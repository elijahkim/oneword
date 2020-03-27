defmodule OneWordWeb.GameLive do
  use OneWordWeb, :live
  alias OneWord.Games.Game
  alias OneWordWeb.GameView

  def render(assigns) do
    case assigns.game_state do
      %{state: :lobby} ->
        Phoenix.View.render(GameView, "lobby.html", assigns)

      %{state: :playing} ->
        Phoenix.View.render(GameView, "game.html", assigns)

      _ ->
        ~L"""
        <h1>loading</h1>
        """
    end
  end

  def mount(_params, _, socket) do
    {:ok, assign(socket, game_state: %{}, has_joined: false, on_team: nil, name: nil)}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    state = Game.get_state(id)

    :ok = Phoenix.PubSub.subscribe(OneWord.PubSub, "game:#{id}")

    {:noreply, assign(socket, id: id, game_state: state)}
  end

  def handle_event("join", %{"username" => name}, %{assigns: %{id: id}} = socket) do
    {team, state} = Game.join(id, name)

    {:noreply,
     assign(
       socket,
       game_state: state,
       has_joined: true,
       on_team: team,
       name: name
     )}
  end

  def handle_event("start", _, %{assigns: %{id: id, game_state: %{state: :lobby}}} = socket) do
    Game.start(id)

    {:noreply, socket}
  end

  def handle_event("select_card", %{"word" => word}, %{assigns: %{id: id}} = socket) do
    Game.guess(id, word)

    {:noreply, socket}
  end

  def handle_event("change_team", %{"team" => team}, %{assigns: %{id: id, name: name}} = socket) do
    {team, state} = Game.change_team(id, team, name)

    {:noreply, assign(socket, on_team: team, game_state: state)}
  end

  def handle_event("change_turn", _, %{assigns: %{id: id}} = socket) do
    Game.change_turn(id)

    {:noreply, socket}
  end

  def handle_event("end_game", _, %{assigns: %{id: id}} = socket) do
    Game.end_game(id)

    {:noreply, socket}
  end

  def handle_info({_, new_state}, socket) do
    {:noreply, assign(socket, :game_state, new_state)}
  end
end
