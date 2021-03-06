# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :cargo_shipping, :generators,
  migration: true,
  binary_id: true,
  sample_binary_id: "11111111-1111-1111-1111-111111111111"

config :cargo_shipping,
  ecto_repos: [CargoShipping.Infra.Repo]

# Configures the endpoint
config :cargo_shipping, CargoShippingWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "wuesgpS3hPNu8tfyjZWoxXkP8jDI4/2XvCfNxFy1cIKwYJvPQgRx2gfpBoda5JrP",
  render_errors: [view: CargoShippingWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: CargoShipping.PubSub,
  live_view: [signing_salt: "LiUj/xCl"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :cargo_shipping, CargoShipping.Mailer, adapter: Swoosh.Adapters.Local

# Swoosh API client is needed for adapters other than SMTP.
config :swoosh, :api_client, false

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.12.18",
  default: [
    args: ~w(js/app.js --bundle --target=es2016 --outdir=../priv/static/assets),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# EventBus topics
config :event_bus,
  id_generator: CargoShipping.ApplicationEvents.Producer,
  topics: [
    :cargo_booked,
    :cargo_booking_failed,
    :cargo_arrived,
    :cargo_misdirected,
    :cargo_was_handled,
    :cargo_handling_rejected,
    :cargo_delivery_updated,
    :cargo_delivery_update_failed,
    :cargo_destination_updated,
    :cargo_destination_update_failed,
    :cargo_itinerary_updated,
    :cargo_itinerary_update_failed,
    :handling_report_accepted,
    :handling_report_rejected
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
