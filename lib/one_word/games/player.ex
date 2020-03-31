defmodule OneWord.Games.Player do
  defstruct [:id, :name, :team, :type]

  def new(args) do
    struct(__MODULE__, args)
  end
end
