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
        <button phx-click="modal">Click Me</Button>
      </div>
    </div>


    <div class="modal-container <%= @display %> animated zoomIn">
      <h1>Red Turn</h1>
    </div>
    """
  end

  def mount(_params, %{"user_id" => _user_id}, socket) do
    IO.inspect(Map.get(socket.assigns, :foo), label: :assigns)
    socket = assign(socket, :foo, :bar)
    {:ok, assign(socket, display: :none)}
  end

  def handle_event("modal", _value, socket) do
    Process.send_after(self(), :hide_modal, 2000)

    {:noreply, assign(socket, display: :block)}
  end

  def handle_event("handle_new_game", _value, socket) do
    {:ok, id} = GamesManager.start_new_game()

    {:noreply, push_redirect(socket, to: Routes.live_path(socket, OneWordWeb.GameLive, id))}
  end

  def handle_info(:hide_modal, socket) do
    {:noreply, assign(socket, display: :none)}
  end
end
