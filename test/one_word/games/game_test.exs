defmodule OneWord.Games.GameTest do
  use ExUnit.Case, async: true
  alias OneWord.Games.{Game, Player}

  describe "#add_player/3" do
    test "It adds the player to blue team if there are more red players" do
      state = %{
        players: %{
          "a" => %Player{
            id: "a",
            team: :red
          }
        }
      }

      state = Game.add_player("b", "test", state)

      assert state.players["b"].team == :blue
    end

    test "It adds the player to red if length(blue) >= length(red)" do
      state = %{
        players: %{
          "a" => %Player{
            id: "a",
            team: :red
          },
          "b" => %Player{
            id: "b",
            team: :blue
          }
        }
      }

      state = Game.add_player("c", "test", state)

      assert state.players["c"].team == :red
    end
  end

  describe "#set_captians/1" do
    test "it sets 2 random players as captain" do
      players = %{
        "a" => %Player{
          id: "a",
          team: :red
        },
        "b" => %Player{
          id: "b",
          team: :blue
        }
      }

      state = %{players: players}

      %{players: new_players} = Game.set_captains(state)

      assert new_players["a"].type == :captain
      assert new_players["b"].type == :captain
    end

    test "it sets exactly 2 random players as captain" do
      players = %{
        "a" => %Player{
          id: "a",
          team: :red
        },
        "b" => %Player{
          id: "b",
          team: :red
        },
        "c" => %Player{
          id: "c",
          team: :red
        },
        "d" => %Player{
          id: "d",
          team: :red
        },
        "e" => %Player{
          id: "e",
          team: :blue
        }
      }

      state = %{players: players}

      %{players: new_players} = Game.set_captains(state)

      captians = Enum.filter(new_players, fn {_k, v} -> v.type == :captain end)

      assert length(captians) == 2
    end
  end
end
