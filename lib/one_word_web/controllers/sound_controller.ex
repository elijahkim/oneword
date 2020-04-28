defmodule OneWordWeb.SoundController do
  use OneWordWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
