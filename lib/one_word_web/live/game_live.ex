defmodule OneWordWeb.GameLive do
  use OneWordWeb, :live
  alias OneWord.GamesManager
  alias OneWord.Games.Game

  def render(assigns) do
    ~L"""
    <%= for card <- @cards do %>
      <%= card.word %>
    <% end %>
    """
  end

  def mount(_params, _, socket) do
    {:ok, assign(socket, cards: [])}
  end

  def handle_params(%{"id" => id}, uri, socket) do
    [{pid, _}] = Registry.lookup(GameRegistry, id)
    cards = Game.get_cards(pid)

    {:noreply, assign(socket, pid: pid, cards: cards)}
  end

  def handle_event("handle_new_game", _value, socket) do
    GamesManager.create_new_game()

    {:noreply, socket}
  end
end
