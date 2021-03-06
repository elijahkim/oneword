defmodule OneWord.Games.Server do
  use GenServer

  alias OneWord.Games.{Game, Player, Log}
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

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {%Log{event: :game_started}, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:end_turn, user_id},
        %{id: id, state: :playing, turn: turn, players: players} = state
      ) do
    case Map.get(players, user_id) do
      %{team: ^turn} -> Game.change_turn(id, user_id)
      _ -> :ok
    end

    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_turn, user_id}, %{turn: turn, state: :playing, id: id} = state) do
    state =
      state
      |> swap_turn()
      |> Map.put(:game_state, :spymaster)

    PubSub.broadcast(
      OneWord.PubSub,
      "game:#{id}",
      {%Log{user_id: user_id, team: turn, event: :change_turn}, state}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast(:end_game, %{state: :playing, id: id} = state) do
    state =
      state
      |> Map.put(:state, :lobby)
      |> Map.put(:game_state, :ready)
      |> reset_players()

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {%Log{event: :end_game}, state})

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

          PubSub.broadcast(
            OneWord.PubSub,
            "game:#{id}",
            {%Log{event: :give_clue, team: turn, user_id: user_id, meta: %{clue: clue}}, state}
          )

          state

        _ ->
          state
      end

    {:noreply, state}
  end

  @impl true
  def handle_cast(
        {:guess, user_id, word},
        %{
          state: :playing,
          game_state: game_state,
          cards: cards,
          id: id,
          turn: turn,
          players: players
        } = state
      ) do
    state =
      case {players[user_id], game_state, Enum.find(cards, fn card -> card.word == word end)} do
        {%{team: ^turn, type: :guesser}, :guesser, %{chosen: false} = card} ->
          state = guess(card, state)

          PubSub.broadcast(
            OneWord.PubSub,
            "game:#{id}",
            {%Log{event: :guess, team: turn, user_id: user_id, meta: %{word: word}}, state}
          )

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

    PubSub.broadcast(
      OneWord.PubSub,
      "game:#{id}",
      {%Log{user_id: user_id, event: :change_team}, state}
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({:join, user_id, username}, %{id: id} = state) do
    state =
      case Game.user_in_game?(user_id, state) do
        true -> state
        false -> add_player(user_id, username, state)
      end

    PubSub.broadcast(
      OneWord.PubSub,
      "game:#{id}",
      {%Log{user_id: user_id, event: :new_team}, state}
    )

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

  defp reset_players(%{players: players} = state) do
    players =
      players
      |> Enum.map(fn {id, player} -> {id, %{player | type: :guesser}} end)
      |> Enum.into(%{})

    Map.put(state, :players, players)
  end

  defp guess(
         %{word: word} = card,
         %{id: id, turn: turn, cards: cards, clues: [clue | clues]} = state
       ) do
    cards =
      Enum.map(cards, fn
        %{word: ^word} -> card
        old_card -> old_card
      end)

    clue =
      case card do
        %{type: ^turn} ->
          %{clue | guesses: clue.guesses + 1}

        _ ->
          clue
      end

    if card.type != turn || clue.guesses > clue.number, do: Game.change_turn(id)

    state
    |> Map.put(:cards, cards)
    |> Map.put(:clues, [clue | clues])
  end

  defp give_clue(%{"word" => word, "number" => number}, %{clues: clues, turn: turn} = state) do
    clues = [%{word: word, number: String.to_integer(number), team: turn, guesses: 0} | clues]

    state
    |> Map.put(:clues, clues)
    |> Map.put(:game_state, :guesser)
  end

  defp swap_turn(%{turn: :red} = state), do: Map.put(state, :turn, :blue)

  defp swap_turn(%{turn: :blue} = state), do: Map.put(state, :turn, :red)
end
