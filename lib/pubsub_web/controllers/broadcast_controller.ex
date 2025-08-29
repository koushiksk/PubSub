defmodule PubsubWeb.BroadcastController do
  use PubsubWeb, :controller

  def send_message(conn, %{"topic" => topic, "message" => message} = _params) do
    # Use the proper MessageBroker for consistent stats and backpressure
    publisher_info = %{
      source: "rest_api",
      client_ip: to_string(:inet_parse.ntoa(conn.remote_ip)),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    case Pubsub.MessageBroker.publish_sync(topic, message, publisher_info) do
      {:ok, stats} ->
        json(conn, %{
          status: "sent",
          topic: topic,
          message: message,
          delivered: stats.delivered,
          dropped: stats.dropped,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :topic_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Topic not found",
          topic: topic
        })

      {:error, reason} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{
          error: "Failed to publish message",
          reason: to_string(reason)
        })
    end
  end

  def send_message(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Missing required parameters",
      required: ["topic", "message"]
    })
  end
end
