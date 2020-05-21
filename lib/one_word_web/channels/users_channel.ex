defmodule OneWordWeb.UsersChannel do
  use Phoenix.Channel
  alias OneWord.Presence

  def join("users:" <> user_id, params, socket) do
    Phoenix.PubSub.subscribe(OneWord.PubSub, "users:#{user_id}")

    {:ok, socket}
  end

  def handle_in("send_answer", params, socket) do
    %{"to" => to, "answer" => answer} = params

    Phoenix.PubSub.broadcast(
      OneWord.PubSub,
      "users:#{to}",
      {:send_answer, %{answer: answer, from: socket.assigns.user_id}}
    )

    {:noreply, socket}
  end

  def handle_info({:send_answer, answer}, socket) do
    IO.inspect("SENDING ANSWER")

    push(socket, "answer", answer)

    {:noreply, socket}
  end

  def handle_info({:new_offer, offer}, socket) do
    push(socket, "new_offer", offer)

    {:noreply, socket}
  end

  def handle_info(msg, socket) do
    {:noreply, socket}
  end
end
