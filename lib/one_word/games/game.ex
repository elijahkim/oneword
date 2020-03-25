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

  @impl true
  def init(id) do
    {:ok,
     %{
       state: :lobby,
       team_1: [],
       team_2: [],
       cards: [],
       id: id
     }}
  end

  @impl true
  def handle_cast(:start, %{state: :lobby, id: id} = state) do
    cards = create_new_game()

    state =
      state
      |> Map.put(:cards, cards)
      |> Map.put(:state, :playing)
      |> Map.put(:turn, :team_1)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:game_started, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:guess, word}, %{state: :playing, id: id, cards: cards} = state) do
    IO.inspect(word)

    cards =
      Enum.map(cards, fn
        %{word: ^word} = card -> Map.put(card, :chosen, true)
        card -> card
      end)

    state =
      state
      |> Map.put(:cards, cards)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:game_started, state})

    {:noreply, state}
  end

  @impl true
  def handle_call({:join, username}, from, %{team_1: team_1, team_2: team_2} = state) do
    state =
      case length(team_1) > length(team_2) do
        true ->
          Map.put(state, :team_2, [username | team_2])

        false ->
          Map.put(state, :team_1, [username | team_1])
      end

    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_cards, _from, %{cards: cards} = state) do
    {:reply, cards, state}
  end

  defp name_via(id) do
    {:via, Registry, {GameRegistry, id}}
  end
end
