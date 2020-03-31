defmodule OneWord.Games.Game do
  use GenServer
  alias OneWord.Games.{Card, Player}
  alias Phoenix.PubSub

  @words "../../../words.csv"
         |> Path.expand(__DIR__)
         |> File.stream!()
         |> CSV.decode!()
         |> Enum.to_list()
         |> List.flatten()

  def shuffle_cards() do
    shuffled = Enum.shuffle(@words)
    {red, shuffled} = Enum.split(shuffled, 9)
    {blue, shuffled} = Enum.split(shuffled, 8)
    {neutral, shuffled} = Enum.split(shuffled, 7)
    {bomb, _shuffled} = Enum.split(shuffled, 1)

    red = Enum.map(red, fn word -> Card.new(%{type: :red, word: word}) end)
    blue = Enum.map(blue, fn word -> Card.new(%{type: :blue, word: word}) end)
    neutral = Enum.map(neutral, fn word -> Card.new(%{type: :neutral, word: word}) end)
    bomb = Enum.map(bomb, fn word -> Card.new(%{type: :bomb, word: word}) end)

    [red | [blue | [neutral | [bomb]]]] |> List.flatten() |> Enum.shuffle()
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name_via(name))
  end

  def get_cards(id) do
    id
    |> name_via
    |> GenServer.call(:get_cards)
  end

  def start(id) do
    id
    |> name_via
    |> GenServer.cast(:start)
  end

  def end_game(id) do
    id
    |> name_via
    |> GenServer.cast(:end_game)
  end

  def guess(id, word) do
    id
    |> name_via
    |> GenServer.cast({:guess, word})
  end

  def change_turn(id) do
    id
    |> name_via
    |> GenServer.cast(:change_turn)
  end

  def get_state(id) do
    id
    |> name_via
    |> GenServer.call(:get_state)
  end

  def join(id, user_id, username) do
    id
    |> name_via
    |> GenServer.cast({:join, user_id, username})
  end

  def change_team(id, user_id) do
    id
    |> name_via
    |> GenServer.cast({:change_team, user_id})
  end

  def user_in_game?(user_id, %{players: players}) do
    Map.has_key?(players, user_id)
  end

  @impl true
  def init(id) do
    initial_state = %{
      state: :lobby,
      players: %{},
      cards: [],
      id: id
    }

    Process.send_after(self(), {:check_state, initial_state}, 1000 * 60 * 30)

    {:ok, initial_state}
  end

  @impl true
  def handle_info({:check_state, state}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:check_state, _old}, state) do
    Process.send_after(self(), {:check_state, state}, 1000 * 60 * 30)

    {:noreply, state}
  end

  @impl true
  def handle_cast(:start, %{state: :lobby, id: id} = state) do
    cards = shuffle_cards()

    state =
      state
      |> Map.put(:cards, cards)
      |> Map.put(:state, :playing)
      |> Map.put(:turn, :red)
      |> set_captains()

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:game_started, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(:change_turn, %{state: :playing, id: id} = state) do
    state = swap_turn(state)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:change_turn, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(:end_game, %{state: :playing, id: id} = state) do
    state = Map.put(state, :state, :lobby)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:end_game, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:guess, word}, %{state: :playing, id: id, cards: cards, turn: turn} = state) do
    cards =
      Enum.map(cards, fn
        %{word: ^word, type: type} = card ->
          if turn != type, do: change_turn(id)
          Map.put(card, :chosen, true)

        card ->
          card
      end)

    state =
      state
      |> Map.put(:cards, cards)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:guess, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_team, user_id}, %{id: id, players: players} = state) do
    players =
      Map.get_and_update(players, user_id, fn
        %{team: :red} = player -> {player, %{player | team: :blue}}
        %{team: :blue} = player -> {player, %{player | team: :red}}
      end)

    state = Map.put(state, :players, players)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:join, user_id, username}, %{id: id} = state) do
    state =
      case user_in_game?(user_id, state) do
        true -> state
        false -> add_player(user_id, username, state)
      end

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:noreply, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_cards, _from, %{cards: cards} = state) do
    {:reply, cards, state}
  end

  def add_player(user_id, name, %{players: players} = state) do
    grouped = Enum.group_by(players, fn {_id, player} -> player.team end)
    red = Map.get(grouped, :red, [])
    blue = Map.get(grouped, :blue, [])

    players =
      case length(red) > length(blue) do
        true ->
          Map.put(
            players,
            user_id,
            Player.new(%{id: user_id, team: :blue, type: :guesser, name: name})
          )

        false ->
          Map.put(
            players,
            user_id,
            Player.new(%{id: user_id, team: :red, type: :guesser, name: name})
          )
      end

    Map.put(state, :players, players)
  end

  def set_captains(%{players: players} = state) do
    %{blue: blue, red: red} = Enum.group_by(players, fn {_id, user} -> user.team end)

    {red_id, red_captain} = Enum.random(red)
    {blue_id, blue_captain} = Enum.random(blue)

    players =
      players
      |> Map.put(red_id, %{red_captain | type: :captain})
      |> Map.put(blue_id, %{blue_captain | type: :captain})

    %{state | players: players}
  end

  defp swap_turn(%{turn: :red} = state), do: Map.put(state, :turn, :blue)

  defp swap_turn(%{turn: :blue} = state), do: Map.put(state, :turn, :red)

  defp name_via(id) do
    {:via, Registry, {GameRegistry, id}}
  end
end
