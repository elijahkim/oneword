defmodule OneWord.Games.Card do
  defstruct [:type, :word, chosen: false]

  def new(args) do
    struct(__MODULE__, args)
  end
end
