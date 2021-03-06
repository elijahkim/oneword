defmodule OneWord.GamesManager do
  use DynamicSupervisor

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  def start_new_game() do
    id = Ecto.UUID.generate()

    {:ok, _pid} =
      DynamicSupervisor.start_child(
        __MODULE__,
        %{
          id: OneWord.Game,
          start: {OneWord.Games.Server, :start_link, [id]},
          restart: :transient
        }
      )

    {:ok, id}
  end

  @impl true
  def init(_init_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
