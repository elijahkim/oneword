defmodule OneWord.Games.Game do
  use GenServer
  alias OneWord.Games.Card
  alias Phoenix.PubSub

  @words "../../../words.csv"
         |> Path.expand(__DIR__)
         |> File.stream!()
         |> CSV.decode!()
         |> Enum.to_list()
         |> List.flatten()

  def create_new_game() do
    shuffled = Enum.shuffle(@words)
    {team_1, shuffled} = Enum.split(shuffled, 9)
    {team_2, shuffled} = Enum.split(shuffled, 8)
    {neutral, shuffled} = Enum.split(shuffled, 7)
    {bomb, _shuffled} = Enum.split(shuffled, 1)

    team_1 = Enum.map(team_1, fn word -> Card.new(%{type: :team_1, word: word}) end)
    team_2 = Enum.map(team_2, fn word -> Card.new(%{type: :team_2, word: word}) end)
    neutral = Enum.map(neutral, fn word -> Card.new(%{type: :neutral, word: word}) end)
    bomb = Enum.map(bomb, fn word -> Card.new(%{type: :bomb, word: word}) end)

    [team_1 | [team_2 | [neutral | [bomb]]]] |> List.flatten() |> Enum.shuffle()
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

  def guess(id, word) do
    id
    |> name_via
    |> GenServer.cast({:guess, word})
  end

  def get_state(id) do
    id
    |> name_via
    |> GenServer.call(:get_state)
  end

  def join(id, username) do
    id
    |> name_via
    |> GenServer.call({:join, username})
  end

  def change_team(id, team, name) do
    id
    |> name_via
    |> GenServer.call({:change_team, team, name})
  end

  @impl true
  def init(id) do
    initial_state = %{
      state: :lobby,
      team_1: [],
      team_2: [],
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
    cards = create_new_game()
    {team_1_captain, team_2_captain} = get_captains(state)

    state =
      state
      |> Map.put(:cards, cards)
      |> Map.put(:state, :playing)
      |> Map.put(:turn, :team_1)
      |> Map.put(:team_1_captain, team_1_captain)
      |> Map.put(:team_2_captain, team_2_captain)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:game_started, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:guess, word}, %{state: :playing, id: id, cards: cards} = state) do
    cards =
      Enum.map(cards, fn
        %{word: ^word} = card -> Map.put(card, :chosen, true)
        card -> card
      end)

    state =
      state
      |> Map.put(:cards, cards)
      |> swap_turn()

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:guess, state})

    {:noreply, state}
  end

  @impl true
  def handle_call(
        {:change_team, "team_1", name},
        _from,
        %{id: id, team_1: team_1, team_2: team_2} = state
      ) do
    team_1 = [name | team_1]
    team_2 = Enum.reject(team_2, &(&1 == name))

    state =
      state
      |> Map.put(:team_1, team_1)
      |> Map.put(:team_2, team_2)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:reply, {:team_1, state}, state}
  end

  @impl true
  def handle_call(
        {:change_team, "team_2", name},
        _from,
        %{id: id, team_1: team_1, team_2: team_2} = state
      ) do
    team_2 = [name | team_2]
    team_1 = Enum.reject(team_1, &(&1 == name))

    state =
      state
      |> Map.put(:team_1, team_1)
      |> Map.put(:team_2, team_2)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:reply, {:team_2, state}, state}
  end

  @impl true
  def handle_call({:join, username}, _from, %{id: id, team_1: team_1, team_2: team_2} = state) do
    {state, team} =
      case length(team_1) > length(team_2) do
        true ->
          {Map.put(state, :team_2, [username | team_2]), :team_2}

        false ->
          {Map.put(state, :team_1, [username | team_1]), :team_1}
      end

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:reply, {team, state}, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_cards, _from, %{cards: cards} = state) do
    {:reply, cards, state}
  end

  defp get_captains(%{team_1: team_1, team_2: team_2}) do
    {Enum.random(team_1), Enum.random(team_2)}
  end

  defp swap_turn(%{turn: :team_1} = state), do: Map.put(state, :turn, :team_2)

  defp swap_turn(%{turn: :team_2} = state), do: Map.put(state, :turn, :team_1)

  defp name_via(id) do
    {:via, Registry, {GameRegistry, id}}
  end
end
