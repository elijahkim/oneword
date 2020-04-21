defmodule OneWord.Games.Game do
  alias OneWord.Games.Card

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

  def get_cards(id) do
    id
    |> name_via
    |> GenServer.call(:get_cards)
  end

  def get_state(id) do
    id
    |> name_via
    |> GenServer.call(:get_state)
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

  def guess(id, user_id, word) do
    id
    |> name_via
    |> GenServer.cast({:guess, user_id, word})
  end

  def end_turn(id, user_id) do
    id
    |> name_via
    |> GenServer.cast({:end_turn, user_id})
  end

  def change_turn(id, user_id \\ nil) do
    id
    |> name_via
    |> GenServer.cast({:change_turn, user_id})
  end

  def give_clue(id, user_id, clue) do
    id
    |> name_via
    |> GenServer.cast({:give_clue, user_id, clue})
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

  def name_via(id) do
    {:via, Registry, {GameRegistry, id}}
  end
end
