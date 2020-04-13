defmodule OneWord.Games.Server do
  use GenServer

  alias OneWord.Games.{Game, Card, Player}
  alias Phoenix.PubSub

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: Game.name_via(name))
  end

  @impl true
  def init(id) do
    initial_state = %{
      state: :lobby,
      game_state: :ready,
      players: %{},
      cards: [],
      clues: [],
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
    cards = Game.shuffle_cards()

    state =
      state
      |> Map.put(:cards, cards)
      |> Map.put(:state, :playing)
      |> Map.put(:game_state, :spymaster)
      |> Map.put(:turn, :red)
      |> set_spymasters()

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:game_started, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(:change_turn, %{state: :playing, id: id} = state) do
    state =
      state
      |> swap_turn()
      |> Map.put(:game_state, :spymaster)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:change_turn, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(:end_game, %{state: :playing, id: id} = state) do
    state =
      state
      |> Map.put(:state, :lobby)
      |> Map.put(:game_state, :ready)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:end_game, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:give_clue, user_id, clue},
        %{id: id, state: :playing, game_state: :spymaster, turn: turn, players: players} = state
      ) do
    player = players[user_id]

    state =
      case player do
        %{team: ^turn, type: :spymaster} ->
          state = give_clue(clue, state)
          PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:give_clue, state})
          state

        _ ->
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:guess, user_id, word},
        %{state: :playing, game_state: :guesser, id: id, turn: turn, players: players} = state
      ) do
    player = players[user_id]

    state =
      case player do
        %{team: ^turn, type: :guesser} ->
          state = guess(word, state)
          PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:guess, state})
          state

        _ ->
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_team, user_id}, %{id: id, players: players} = state) do
    {_changed, players} =
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
      case Game.user_in_game?(user_id, state) do
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

  def set_spymasters(%{players: players} = state) do
    %{blue: blue, red: red} = Enum.group_by(players, fn {_id, user} -> user.team end)

    {red_id, red_spymaster} = Enum.random(red)
    {blue_id, blue_spymaster} = Enum.random(blue)

    players =
      players
      |> Map.put(red_id, %{red_spymaster | type: :spymaster})
      |> Map.put(blue_id, %{blue_spymaster | type: :spymaster})

    %{state | players: players}
  end

  defp guess(word, %{id: id, turn: turn, cards: cards} = state) do
    cards =
      Enum.map(cards, fn
        %{word: ^word, type: type} = card ->
          if turn != type, do: Game.change_turn(id)
          Map.put(card, :chosen, true)

        card ->
          card
      end)

    Map.put(state, :cards, cards)
  end

  defp give_clue(%{"word" => word, "number" => number}, %{clues: clues, turn: turn} = state) do
    clues = [%{word: word, number: number, team: turn} | clues]

    state
    |> Map.put(:clues, clues)
    |> Map.put(:game_state, :guesser)
  end

  defp swap_turn(%{turn: :red} = state), do: Map.put(state, :turn, :blue)

  defp swap_turn(%{turn: :blue} = state), do: Map.put(state, :turn, :red)
end
