defmodule OneWordWeb.GameView do
  use OneWordWeb, :view

  def get_remaining(assigns, team) do
    Enum.count(assigns.game_state.cards, fn
      %{type: ^team, chosen: false} -> true
      _ -> false
    end)
  end

  def is_captain?(%{red_captain: t1, blue_captain: t2}, user_id) do
    user_id in [t1, t2]
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
