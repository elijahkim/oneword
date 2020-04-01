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
       user_id: user_id
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

  def handle_info({_, new_state}, socket) do
    IO.inspect(new_state)
    {:noreply, assign(socket, :game_state, new_state)}
  end
end
