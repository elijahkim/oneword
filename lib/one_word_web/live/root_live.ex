defmodule OneWordWeb.RootLive do
  use Phoenix.LiveView, layout: {OneWordWeb.LayoutView, "live.html"}

  def render(assigns) do
    ~L"""
    <h1>Hi</h1>
    """
  end

  def mount(_params, _, socket) do
    {:ok, socket}
  end
end
