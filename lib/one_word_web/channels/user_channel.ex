defmodule OneWordWeb.UserChannel do
  use Phoenix.Channel
  alias OneWord.Presence
  alias Phoenix.PubSub

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

  def handle_in("send_offer:" <> user_id, params, socket) do
    PubSub.broadcast(
      OneWord.PubSub,
      "users:#{user_id}",
      {:new_offer, %{offer: params, from: socket.assigns.user_id}}
    )

    {:noreply, socket}
  end

  def handle_in("new_location", position, socket) do
    Presence.update(socket, socket.assigns.user_id, fn map ->
      Map.merge(map, %{position: position})
    end)

    {:noreply, socket}
  end
end
