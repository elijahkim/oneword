defmodule OneWordWeb.GameLive do
  use OneWordWeb, :live
  alias OneWord.GamesManager
  alias OneWord.Games.Game

  def render(assigns) do
    case assigns.game_state do
      %{state: :lobby} ->
        ~L"""
        <h1>Team 1</h1>
        <ul>
          <%= for player <- @game_state.team_1 do %>
            <li><%= player %></li>
          <% end %>
        </ul>
        <h1>Team 2</h1>
        <ul>
          <%= for player <- @game_state.team_2 do %>
            <li><%= player %></li>
          <% end %>
        </ul>

        <form phx-submit="join">
          <input type="text" name="username" phx-debounce="blur"/>

          <button type=submit>
            Join
          </button>
        </form>

        <button phx-click="start">
          Start
        </button>
        """

      %{state: :playing} ->
        ~L"""
        <h1><%= assigns.game_state.turn %>'s Turn</h1>
        <div class="game__cards-container">
          <%= for card <- @game_state.cards do %>
            <button class=<%= get_class(card) %> phx-click="select_card" phx-value-word="<%= card.word %>">
              <p clasa="game__card-text">
                <%= card.word %>
              </p>
            </button>
          <% end %>
        </div>
        """

      _ ->
        ~L"""
        <h1>loading</h1>
        """
    end
  end

  def get_class(card) do
    case card do
      %{chosen: true, type: :team_1} -> "game__card-container__chosen-team-1"
      %{chosen: true, type: :team_2} -> "game__card-container__chosen-team-2"
      %{chosen: true, type: :neutral} -> "game__card-container__chosen-neutral"
      %{chosen: true, type: :bomb} -> "game__card-container__chosen-bomb"
      %{chosen: false} -> "game__card-container"
    end
  end

  def mount(_params, _, socket) do
    {:ok, assign(socket, game_state: %{}, test_word: "Yo Yo")}
  end

  def handle_params(%{"id" => id}, _uri, socket) do
    state = Game.get_state(id)

    :ok = Phoenix.PubSub.subscribe(OneWord.PubSub, "game:#{id}")

    {:noreply, assign(socket, id: id, game_state: state)}
  end

  def handle_event("join", %{"username" => name}, %{assigns: %{id: id}} = socket) do
    state = Game.join(id, name)

    {:noreply, assign(socket, game_state: state)}
  end

  def handle_event("start", _, %{assigns: %{id: id, game_state: %{state: :lobby}}} = socket) do
    Game.start(id)

    {:noreply, socket}
  end

  def handle_event("select_card", %{"word" => word}, %{assigns: %{id: id}} = socket) do
    Game.guess(id, word)

    {:noreply, socket}
  end

  def handle_info({_, new_state}, socket) do
    IO.inspect(new_state)
    {:noreply, assign(socket, :game_state, new_state)}
  end
end
