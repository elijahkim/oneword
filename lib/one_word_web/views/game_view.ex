defmodule OneWordWeb.GameView do
  use OneWordWeb, :view

  def get_remaining(assigns, team) do
    Enum.count(assigns.game_state.cards, fn
      %{type: ^team, chosen: false} -> true
      _ -> false
    end)
  end

  def is_captain(%{team_1_captain: t1, team_2_captain: t2}, name) do
    name in [t1, t2]
  end

  def get_spymaster_class(card) do
    modifier =
      case card do
        %{chosen: true} ->
          "game__card__revealed"

        _ ->
          ""
      end

    "#{get_class(%{card | chosen: true})} #{modifier}"
  end

  def get_class(card) do
    modifier =
      case card do
        %{chosen: true, type: :team_1} -> "game__card-team-1"
        %{chosen: true, type: :team_2} -> "game__card-team-2"
        %{chosen: true, type: :neutral} -> "game__card-neutral"
        %{chosen: true, type: :bomb} -> "game__card-bomb"
        _ -> ""
      end

    "game__card-container " <> modifier
  end
end
