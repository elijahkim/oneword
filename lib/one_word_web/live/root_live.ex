defmodule OneWordWeb.RootLive do
  use OneWordWeb, :live
  alias OneWord.GamesManager

  def render(assigns) do
    ~L"""
    <button phx-click="handle_new_game">New Game</button>
    """
  end

  def mount(_params, %{"uuid" => uuid}, socket) do
    {:ok, socket}
  end

  def handle_event("handle_new_game", _value, socket) do
    {:ok, id} = GamesManager.start_new_game()

    {:noreply, push_redirect(socket, to: Routes.live_path(socket, OneWordWeb.GameLive, id))}
  end
end
