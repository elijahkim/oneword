defmodule OneWordWeb.Plugs.Identifier do
  import Plug.Conn

  def init(default), do: default

  def call(conn, _default) do
    case get_session(conn, "user_id") do
      nil -> put_session(conn, "user_id", Ecto.UUID.generate())
      _user_id -> conn
    end
  end
end
