defmodule CargoShippingApplication do
  @moduledoc """
  CargoShippingApplication is the top-level application boundary.
  """

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications

  use Application
  use Boundary, deps: [CargoShipping, CargoShippingWeb], exports: []

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Ecto repository
      CargoShipping.Infra.Repo,
      # Start the Telemetry supervisor
      CargoShippingWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: CargoShipping.PubSub},
      # Start the Endpoint (http/https)
      CargoShippingWeb.Endpoint,
      # Start a worker by calling: CargoShipping.Worker.start_link(arg)
      CargoShipping.ApplicationEvents.Consumer,
      CargoShipping.LocationService,
      CargoShipping.VoyageService
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: CargoShipping.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    CargoShippingWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
