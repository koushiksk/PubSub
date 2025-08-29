defmodule PubsubWeb.PageController do
  use PubsubWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    render(conn, :home, layout: false)
  end

  def websocket_info(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "WebSocket endpoint accessed via HTTP",
      message: "This endpoint is for WebSocket connections only",
      usage: %{
        correct_websocket_url: "ws://#{conn.host}:#{conn.port}/ws",
        example_connection: "Connect using WebSocket client to ws://#{conn.host}:#{conn.port}/ws",
        documentation: "See README.md for WebSocket usage examples"
      },
      supported_operations: [
        "ping - Health check",
        "subscribe - Subscribe to topics",
        "unsubscribe - Remove topic subscription",
        "publish - Send messages to topics"
      ]
    })
  end
end
