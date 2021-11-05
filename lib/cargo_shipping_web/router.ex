defmodule CargoShippingWeb.Router do
  use CargoShippingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {CargoShippingWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    # plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  ## The following scopes are organized by application user

  scope "/clerks", CargoShippingWeb do
    pipe_through :browser

    get "/", PageController, :clerks
    live "/tracking", CargoLive.Search, :index
  end

  scope "/managers", CargoShippingWeb do
    pipe_through :browser

    get "/", PageController, :managers
    live "/cargos", CargoLive.Index, :index
    live "/cargos/new", CargoLive.New, :new
    live "/cargos/id/:tracking_id", CargoLive.Show, :show
    live "/cargos/id/:tracking_id/destination/edit", CargoLive.EditDestination, :edit
    live "/cargos/id/:tracking_id/route/edit", CargoLive.EditRoute, :edit
    live "/events", HandlingEventLive.Index, :all
    live "/events/id/:tracking_id", HandlingEventLive.Index, :index
    live "/reports/new", HandlingReportLive.New, :new
    live "/voyages", VoyageLive.Index, :index
    live "/voyages/new", VoyageLive.New, :new
    live "/voyages/number/:voyage_number", VoyageLive.Show, :show
  end

  ## This scope handles JSON requests and responses

  scope "/api", CargoShippingWeb do
    pipe_through :api

    resources "/handling_reports", HandlingReportController, only: [:index, :create, :show]
  end

  ## This scope handles landing page, logins, etc.

  scope "/", CargoShippingWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  # Enables LiveDashboard only for development
  #
  # If you want to use the LiveDashboard in production, you should put
  # it behind authentication and allow only admins to access it.
  # If your application does not have an admins-only section yet,
  # you can use Plug.BasicAuth to set up some basic authentication
  # as long as you are also using SSL (which you should anyway).
  if Mix.env() in [:dev, :test] do
    import Phoenix.LiveDashboard.Router

    scope "/" do
      pipe_through :browser
      live_dashboard "/dashboard", metrics: CargoShippingWeb.Telemetry
    end
  end

  # Enables the Swoosh mailbox preview in development.
  #
  # Note that preview only shows emails that were sent by the same
  # node running the Phoenix server.
  if Mix.env() == :dev do
    scope "/dev" do
      pipe_through :browser

      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
