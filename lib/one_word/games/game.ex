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

  def user_in_game?(user_id, state) do
    Enum.member?(user_ids(state), user_id)
  end

  @impl true
  def init(id) do
    initial_state = %{
      state: :lobby,
      red: [],
      blue: [],
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
    {red_captain, blue_captain} = get_captains(state)

    state =
      state
      |> Map.put(:cards, cards)
      |> Map.put(:state, :playing)
      |> Map.put(:turn, :red)
      |> Map.put(:red_captain, red_captain.id)
      |> Map.put(:blue_captain, blue_captain.id)

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
  def handle_cast({:guess, word}, %{state: :playing, id: id, cards: cards} = state) do
    cards =
      Enum.map(cards, fn
        %{word: ^word} = card -> Map.put(card, :chosen, true)
        card -> card
      end)

    state =
      state
      |> Map.put(:cards, cards)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:guess, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:change_team, user_id}, %{id: id, red: red, blue: blue} = state) do
    {red, blue} =
      case {find_member(red, user_id), find_member(blue, user_id)} do
        {user, nil} when not is_nil(user) ->
          {Enum.reject(red, &(&1 == user)), [user | blue]}

        {nil, user} when not is_nil(user) ->
          {[user | red], Enum.reject(blue, &(&1 == user))}
      end

    state =
      state
      |> Map.put(:red, red)
      |> Map.put(:blue, blue)

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:noreply, state}
  end

  @impl true
  def handle_cast({:join, user_id, username}, %{id: id} = state) do
    state =
      case user_in_game?(user_id, state) do
        true -> state
        false -> add_user(user_id, username, state)
      end

    PubSub.broadcast(OneWord.PubSub, "game:#{id}", {:new_team, state})

    {:noreply, state}
  end

  defp user_ids_for_team(team) do
    Enum.map(team, & &1.id)
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:get_cards, _from, %{cards: cards} = state) do
    {:reply, cards, state}
  end

  defp add_user(user_id, name, %{red: red, blue: blue} = state) do
    case length(red) > length(blue) do
      true ->
        Map.put(state, :blue, [%{id: user_id, name: name} | blue])

      false ->
        Map.put(state, :red, [%{id: user_id, name: name} | red])
    end
  end

  def find_member(team, id) do
    Enum.find(team, &(&1.id == id))
  end

  defp user_ids(%{red: red, blue: blue}) do
    user_ids_for_team(red) ++ user_ids_for_team(blue)
  end

  defp get_captains(%{red: red, blue: blue}) do
    {Enum.random(red), Enum.random(blue)}
  end

  defp swap_turn(%{turn: :red} = state), do: Map.put(state, :turn, :blue)

  defp swap_turn(%{turn: :blue} = state), do: Map.put(state, :turn, :red)

  defp name_via(id) do
    {:via, Registry, {GameRegistry, id}}
  end
end
