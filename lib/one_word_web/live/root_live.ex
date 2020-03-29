defmodule OneWordWeb.RootLive do
  use OneWordWeb, :live
  alias OneWord.GamesManager

  def render(assigns) do
    ~L"""
    <div class="root__container">
      <div class="root__inner-container">
        <div class="root__header-container">
          <h4>Welcome to One Word</h4>
        </div>
        <button phx-click="handle_new_game">New Game</button>
      </div>
    </div>
    """
  end

  def mount(_params, %{"user_id" => _user_id}, socket) do
    {:ok, socket}
  end

  def handle_event("handle_new_game", _value, socket) do
    {:ok, id} = GamesManager.start_new_game()

    {:noreply, push_redirect(socket, to: Routes.live_path(socket, OneWordWeb.GameLive, id))}
  end
end
