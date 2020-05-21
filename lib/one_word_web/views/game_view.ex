defmodule OneWordWeb.GameView do
  use OneWordWeb, :view
  alias OneWord.Games.Log

  def get_team(team, %{players: players}) do
    Enum.filter(players, fn {_id, player} -> player.team == team end)
  end

  def get_remaining(assigns, team) do
    Enum.count(assigns.game_state.cards, fn
      %{type: ^team, chosen: false} -> true
      _ -> false
    end)
  end

  def clue_allowed?(%{game_state: :spymaster, players: players, turn: turn}, user_id) do
    player = players[user_id]

    player.type == :spymaster && player.team == turn
  end

  def clue_allowed?(_game_state, _user_id) do
    false
  end

  def spymaster?(%{players: players}, user_id) do
    players[user_id].type == :spymaster
  end

  def get_spymaster_class(card) do
    modifier =
      case card do
        %{chosen: true} ->
          "game__card__revealed animated flip"

        _ ->
          ""
      end

    base_class =
      %{card | chosen: true}
      |> get_class()
      |> String.replace_trailing(" animated flip", "")

    "#{base_class} #{modifier}"
  end

  def get_class(card) do
    modifier =
      case card do
        %{chosen: true, type: :red} -> "game__card-red animated flip"
        %{chosen: true, type: :blue} -> "game__card-blue animated flip"
        %{chosen: true, type: :neutral} -> "game__card-neutral animated flip"
        %{chosen: true, type: :bomb} -> "game__card-bomb animated flip"
        _ -> ""
      end

    "game__card-container " <> modifier
  end

  def render_log(
        %Log{
          event: :guess,
          user_id: user_id,
          team: team,
          meta: %{word: word}
        },
        %{players: players}
      ) do
    player = players[user_id]

    ~E"""
    <p>
      <span class="<%= team %>-modifier"><%= player.name %></span> Guessed: <%= word %>
    </p>
    """
  end

  def render_log(
        %Log{
          event: :give_clue,
          user_id: user_id,
          team: team,
          meta: %{clue: %{"word" => word, "number" => number}}
        },
        %{players: players}
      ) do
    player = players[user_id]

    ~L"""
    <p>
      <span class="<%= team %>-modifier"><%= player.name %></span> gave clue: <%= word %>, <%= number %>
    </p>
    """
  end

  def render_log(%Log{event: :end_game}, _game_state) do
    ~E"""
    <p>
      Game Ended
    </p>
    """
  end

  def render_log(%Log{event: :change_turn, team: team}, _game_state) do
    ~E"""
    <p>
      <span class="<%= team %>-modifier"><%= team %></span> turn ended
    </p>
    """
  end

  def render_log(%Log{event: :game_started}, _game_state) do
    ~E"""
    <p>
      <span>Game started</span>
    </p>
    """
  end

  def render_log(log, _game_state) do
    IO.inspect(log)
    ""
  end
end
