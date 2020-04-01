defmodule OneWordWeb.GameView do
  use OneWordWeb, :view

  def get_team(team, %{players: players}) do
    Enum.filter(players, fn {_id, player} -> player.team == team end)
  end

  def get_remaining(assigns, team) do
    Enum.count(assigns.game_state.cards, fn
      %{type: ^team, chosen: false} -> true
      _ -> false
    end)
  end

  def is_spymaster?(%{players: players}, user_id) do
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
end
