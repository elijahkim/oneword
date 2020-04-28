defmodule OneWordWeb.UserChannel do
  use Phoenix.Channel
  alias OneWord.Presence

  def join("users", params, socket) do
    send(self(), :after_join)
    {:ok, socket}
  end

  def handle_info(:after_join, socket) do
    {:ok, _} =
      Presence.track(socket, socket.assigns.user_id, %{
        online_at: inspect(System.system_time(:second))
      })

    push(socket, "presence_state", Presence.list(socket))
    {:noreply, socket}
  end

  def handle_in("new_location", position, socket) do
    Presence.update(socket, socket.assigns.user_id, %{
      position: position
    })

    {:noreply, socket}
  end
end
