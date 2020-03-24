# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

config :one_word,
  ecto_repos: [OneWord.Repo],
  generators: [binary_id: true]

# Configures the endpoint
config :one_word, OneWordWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "FGLOSxtJvOc/8ds6kvcmwQQIFOhAxp9p+unriTHenRJrYXH31TSFUwjd9DjBKRrh",
  render_errors: [view: OneWordWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: OneWord.PubSub, adapter: Phoenix.PubSub.PG2],
  live_view: [signing_salt: "E+0239odfWebhJB3ZgCZri3+l87gwv32"]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
