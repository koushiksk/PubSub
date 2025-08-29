defmodule PubsubWeb.Router do
  use PubsubWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PubsubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PubsubWeb do
    pipe_through :browser

    get "/", PageController, :home

    # WebSocket endpoint info - helps users who try to access /ws via HTTP
    # get "/ws", PageController, :websocket_info
  end

  # API routes for pub/sub system
  scope "/api", PubsubWeb do
    pipe_through :api

    # Health and observability
    get "/health", HealthController, :check
    get "/stats", StatsController, :show

    # Topic management
    resources "/topics", TopicController, except: [:new, :edit, :update] do
      # Custom routes for topics can be added here if needed
    end

    # Message broadcasting (legacy endpoint)
    post "/broadcast", BroadcastController, :send_message
  end
end
