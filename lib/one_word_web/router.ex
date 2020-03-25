defmodule OneWordWeb.Router do
  use OneWordWeb, :router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", OneWordWeb do
    pipe_through :browser

    live "/", RootLive
    live "/game/:id", GameLive
  end
end
