use Mix.Config

# Configure your database
config :one_word, OneWord.Repo,
  username: "postgres",
  password: "postgres",
  database: "one_word_test",
  hostname: "localhost",
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :one_word, OneWordWeb.Endpoint,
  http: [port: 4002],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn
