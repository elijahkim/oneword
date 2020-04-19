defmodule OneWordWeb.GameLive do
  use OneWordWeb, :live
  alias OneWord.Games.Game
  alias OneWordWeb.GameView

  def render(assigns) do
    case assigns do
      %{game_state: %{state: :lobby}} ->
        Phoenix.View.render(GameView, "lobby.html", assigns)

      %{has_joined: false} ->
        Phoenix.View.render(GameView, "lobby.html", assigns)

      %{game_state: %{state: :playing}} ->
        Phoenix.View.render(GameView, "game.html", assigns)

      _ ->
        ~L"""
        <h1>loading</h1>
        """
    end
  end

  def mount(_params, %{"user_id" => user_id}, socket) do
    {:ok,
     assign(
       socket,
       game_state: %{},
       has_joined: false,
       on_team: nil,
       user_id: user_id,
       logs: []
     )}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    game_state = Game.get_state(id)
    %{assigns: %{user_id: user_id}} = socket

    has_joined = Game.user_in_game?(user_id, game_state)

    :ok = Phoenix.PubSub.subscribe(OneWord.PubSub, "game:#{id}")

    {:noreply,
     assign(
       socket,
       id: id,
       game_state: game_state,
       has_joined: has_joined
     )}
  end

  def handle_event(
        "join",
        %{"username" => name},
        %{assigns: %{user_id: user_id, id: id}} = socket
      ) do
    Game.join(id, user_id, name)

    {:noreply,
     assign(
       socket,
       has_joined: true
     )}
  end

  def handle_event("start", _, %{assigns: %{id: id, game_state: %{state: :lobby}}} = socket) do
    Game.start(id)

    {:noreply, socket}
  end

  def handle_event(
        "select_card",
        %{"word" => word},
        %{assigns: %{user_id: user_id, id: id}} = socket
      ) do
    Game.guess(id, user_id, word)

    {:noreply, socket}
  end

  def handle_event("change_team", _, %{assigns: %{id: id, user_id: user_id}} = socket) do
    Game.change_team(id, user_id)

    {:noreply, socket}
  end

  def handle_event("change_turn", _, %{assigns: %{id: id}} = socket) do
    Game.change_turn(id)

    {:noreply, socket}
  end

  def handle_event("end_game", _, %{assigns: %{id: id}} = socket) do
    Game.end_game(id)

    {:noreply, socket}
  end

  def handle_event(
        "give_clue",
        %{"clue" => clue},
        %{assigns: %{id: id, user_id: user_id}} = socket
      ) do
    Game.give_clue(id, user_id, clue)

    {:noreply, socket}
  end

  def handle_info(broadcast, %{assigns: %{logs: logs}} = socket) do
    {event, new_state} = handle_broadcast(broadcast)

    logs =
      case event do
        nil -> logs
        event -> [event | logs]
      end

    {:noreply, assign(socket, game_state: new_state, logs: logs)}
  end

  defp handle_broadcast({:game_started, state}) do
    {"Game Started", state}
  end

  defp handle_broadcast({:change_turn, state}) do
    {"Change Turn", state}
  end

  defp handle_broadcast({:end_game, state}) do
    {"Game Ended", state}
  end

  defp handle_broadcast({:give_clue, %{clues: [clue | _clues]} = state}) do
    %{word: word, number: number, team: team} = clue

    {"Team #{team} - New Clue - #{word} - #{number}", state}
  end

  defp handle_broadcast({:guess, word, %{turn: turn, clues: [clue | _clues]} = state}) do
    %{number: number, guesses: guesses, team: ^turn} = clue

    {"Team #{turn} - Guess - #{word} - #{number - guesses + 1} guesses remaining", state}
  end

  defp handle_broadcast({:new_team, state}) do
    {nil, state}
  end

  defp handle_broadcast({:change_team, state}) do
    {nil, state}
  end

  defp handle_broadcast({:join, state}) do
    {nil, state}
  end
end
