defmodule OneWordWeb do
  @moduledoc """
  The entrypoint for defining your web interface, such
  as controllers, views, channels and so on.

  This can be used in your application as:

      use OneWordWeb, :controller
      use OneWordWeb, :view

  The definitions below will be executed for every view,
  controller, etc, so keep them short and clean, focused
  on imports, uses and aliases.

  Do NOT define functions inside the quoted expressions
  below. Instead, define any helper function in modules
  and import those modules here.
  """

  def controller do
    quote do
      use Phoenix.Controller, namespace: OneWordWeb

      import Plug.Conn
      import OneWordWeb.Gettext
      import Phoenix.LiveView.Controller
      alias OneWordWeb.Router.Helpers, as: Routes
    end
  end

  def view do
    quote do
      use Phoenix.View,
        root: "lib/one_word_web/templates",
        namespace: OneWordWeb

      # Import convenience functions from controllers
      import Phoenix.Controller, only: [get_flash: 1, get_flash: 2, view_module: 1]

      # Use all HTML functionality (forms, tags, etc)
      use Phoenix.HTML

      import OneWordWeb.ErrorHelpers
      import OneWordWeb.Gettext
      import Phoenix.LiveView.Helpers
      alias OneWordWeb.Router.Helpers, as: Routes
    end
  end

  def live do
    quote do
      use Phoenix.LiveView, layout: {OneWordWeb.LayoutView, "live.html"}
      alias OneWordWeb.Router.Helpers, as: Routes
      use Phoenix.HTML
    end
  end

  def router do
    quote do
      use Phoenix.Router
      import Plug.Conn
      import Phoenix.Controller
    end
  end

  def channel do
    quote do
      use Phoenix.Channel
      import OneWordWeb.Gettext
    end
  end

  @doc """
  When used, dispatch to the appropriate controller/view/etc.
  """
  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
