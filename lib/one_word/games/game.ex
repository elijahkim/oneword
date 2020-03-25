defmodule OneWord.Games.Game do
  use GenServer
  alias OneWord.Games.Card

  @words "../../../words.csv"
         |> Path.expand(__DIR__)
         |> IO.inspect()
         |> File.stream!()
         |> CSV.decode!()
         |> Enum.to_list()
         |> List.flatten()

  def create_new_game() do
    shuffled = Enum.shuffle(@words)
    {team_1, shuffled} = Enum.split(shuffled, 9)
    {team_2, shuffled} = Enum.split(shuffled, 8)
    {neutral, shuffled} = Enum.split(shuffled, 7)
    {bomb, shuffled} = Enum.split(shuffled, 1)

    team_1 = Enum.map(team_1, fn word -> Card.new(%{type: :team_1, word: word}) end)
    team_2 = Enum.map(team_2, fn word -> Card.new(%{type: :team_2, word: word}) end)
    neutral = Enum.map(neutral, fn word -> Card.new(%{type: :neutral, word: word}) end)
    bomb = Enum.map(bomb, fn word -> Card.new(%{type: :bomb, word: word}) end)

    [team_1 | [team_2 | [neutral | [bomb]]]] |> List.flatten() |> Enum.shuffle()
  end

  def start_link(name) do
    GenServer.start_link(__MODULE__, name, name: name)
  end

  def get_cards(pid) do
    GenServer.call(pid, :get_cards)
  end

  @impl true
  def init(_stack) do
    cards = create_new_game()
    {:ok, %{cards: cards}}
  end

  def handle_call(:get_cards, _from, %{cards: cards} = state) do
    {:reply, cards, state}
  end
end
