defmodule OneWord.Presence do
  use Phoenix.Presence,
    otp_app: :one_word,
    pubsub_server: OneWord.PubSub
end
