defmodule CargoShippingWeb.Router do
  use CargoShippingWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, {CargoShippingWeb.LayoutView, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", CargoShippingWeb do
    pipe_through :browser

    get "/", PageController, :index
  end

  scope "/tracking", CargoShippingWeb do
    ## The following scopes are organized by application user
    scope "/clerks" do
      live "/cargoes/:tracking_id", CargoLive.Show, :show
      # resources "/", ClerkController, only: [:index]
    end

    scope "/opsmanagers" do
      live "/events", HandlingEventLive.Index, :index
      live "/events/:id", HandlingEventLive.Show, :show
      # resources "/", OpsManagerController, only: [:index]
    end

    ## This scope handles JSON requests and responses
    scope "/api" do
      pipe_through :api
    end
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
