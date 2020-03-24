defmodule OneWord.Repo do
  use Ecto.Repo,
    otp_app: :one_word,
    adapter: Ecto.Adapters.Postgres
end
