defmodule PubsubWeb.GenericChannel do
  use PubsubWeb, :channel
  require Logger

  @impl true
  def join("pubsub", _payload, socket) do
    # Store subscriber info and clean up on disconnect
    socket = assign(socket, :subscribed_topics, MapSet.new())
    Logger.info("Client connected: #{inspect(socket.transport_pid)}")

    response = build_response("info", %{
      message: "Connected successfully",
      client_id: inspect(socket.transport_pid)
    })

    {:ok, response, socket}
  end

  # Handle ping messages for health checks
  @impl true
  def handle_in("ping", payload, socket) do
    request_id = get_request_id(payload)

    response = build_response("pong", %{
      message: "pong",
      client_id: inspect(socket.transport_pid)
    }, request_id)

    {:reply, {:ok, response}, socket}
  end

  # Handle subscribe operation
  @impl true
  def handle_in("subscribe", payload, socket) do
    request_id = get_request_id(payload)

    case validate_subscribe_payload(payload) do
      {:ok, topic} ->
        handle_subscribe(topic, request_id, socket)

      {:error, error_message} ->
        response = build_error_response("BAD_REQUEST", error_message, request_id)
        {:reply, {:error, response}, socket}
    end
  end

  # Handle unsubscribe operation
  @impl true
  def handle_in("unsubscribe", payload, socket) do
    request_id = get_request_id(payload)

    case validate_unsubscribe_payload(payload) do
      {:ok, topic} ->
        handle_unsubscribe(topic, request_id, socket)

      {:error, error_message} ->
        response = build_error_response("BAD_REQUEST", error_message, request_id)
        {:reply, {:error, response}, socket}
    end
  end

  # Handle publish operation
  @impl true
  def handle_in("publish", payload, socket) do
    request_id = get_request_id(payload)

    case validate_publish_payload(payload) do
      {:ok, {topic, message}} ->
        handle_publish(topic, message, request_id, socket)

      {:error, error_message} ->
        response = build_error_response("BAD_REQUEST", error_message, request_id)
        {:reply, {:error, response}, socket}
    end
  end

  # Catch-all for unknown messages
  @impl true
  def handle_in(event, payload, socket) do
    request_id = get_request_id(payload)

    response = build_error_response("BAD_REQUEST",
      "Unknown event type '#{event}'. Supported: ping, subscribe, unsubscribe, publish",
      request_id)

    {:reply, {:error, response}, socket}
  end

  # Handle incoming pubsub messages from the message broker
  @impl true
  def handle_info({:pubsub_message, message_payload}, socket) do
    # Ensure the message has proper format
    formatted_message = case message_payload do
      %{topic: topic, message: message} when is_map(message) ->
        # Message already has proper structure
        build_event_response(topic, message)

      %{topic: topic, message: message} ->
        # Wrap simple message in proper structure
        message_with_id = %{
          id: generate_uuid(),
          payload: message
        }
        build_event_response(topic, message_with_id)

      _ ->
        # Fallback for malformed messages
        build_event_response("system", %{
          id: generate_uuid(),
          payload: message_payload
        })
    end

    push(socket, "message", formatted_message)
    {:noreply, socket}
  end

  # Handle client disconnect
  @impl true
  def terminate(reason, socket) do
    Logger.info("Client disconnected: #{inspect(socket.transport_pid)}, reason: #{inspect(reason)}")

    # Clean up all subscriptions for this client
    Pubsub.SubscriptionManager.cleanup_subscriber(self())

    :ok
  end

  # Private helper functions

  defp handle_subscribe(topic, request_id, socket) do
    case Pubsub.TopicManager.topic_exists?(topic) do
      false ->
        response = build_error_response("TOPIC_NOT_FOUND", "Topic does not exist: #{topic}", request_id)
        {:reply, {:error, response}, socket}

      true ->
        case Pubsub.SubscriptionManager.subscribe(topic, self()) do
          :ok ->
            # Track subscription in socket state
            subscribed_topics = MapSet.put(socket.assigns.subscribed_topics, topic)
            socket = assign(socket, :subscribed_topics, subscribed_topics)

            response = build_ack_response(topic, %{
              action: "subscribed",
              subscriber_count: get_subscriber_count(topic)
            }, request_id)

            Logger.info("Client #{inspect(socket.transport_pid)} subscribed to topic: #{topic}")
            {:reply, {:ok, response}, socket}

          error ->
            response = build_error_response("SUBSCRIPTION_FAILED",
              "Failed to subscribe to #{topic}: #{inspect(error)}", request_id)
            {:reply, {:error, response}, socket}
        end
    end
  end

  defp handle_unsubscribe(topic, request_id, socket) do
    case Pubsub.SubscriptionManager.unsubscribe(topic, self()) do
      :ok ->
        # Remove from socket state
        subscribed_topics = MapSet.delete(socket.assigns.subscribed_topics, topic)
        socket = assign(socket, :subscribed_topics, subscribed_topics)

        response = build_ack_response(topic, %{
          action: "unsubscribed",
          subscriber_count: get_subscriber_count(topic)
        }, request_id)

        Logger.info("Client #{inspect(socket.transport_pid)} unsubscribed from topic: #{topic}")
        {:reply, {:ok, response}, socket}

      error ->
        response = build_error_response("UNSUBSCRIBE_FAILED",
          "Failed to unsubscribe from #{topic}: #{inspect(error)}", request_id)
        {:reply, {:error, response}, socket}
    end
  end

  defp handle_publish(topic, message, request_id, socket) do
    publisher_info = %{
      source: "websocket",
      client_pid: inspect(socket.transport_pid),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      request_id: request_id
    }

    case Pubsub.MessageBroker.publish_sync(topic, message, publisher_info) do
      {:ok, stats} ->
        response = build_ack_response(topic, %{
          action: "published",
          message_id: generate_uuid(),
          stats: stats
        }, request_id)
        {:reply, {:ok, response}, socket}

      {:error, :topic_not_found} ->
        response = build_error_response("TOPIC_NOT_FOUND", "Topic does not exist: #{topic}", request_id)
        {:reply, {:error, response}, socket}

      {:error, reason} ->
        response = build_error_response("PUBLISH_FAILED",
          "Failed to publish to #{topic}: #{inspect(reason)}", request_id)
        {:reply, {:error, response}, socket}
    end
  end

  # Validation functions

  defp validate_subscribe_payload(%{"topic" => topic}) when is_binary(topic) and topic != "" do
    case validate_topic_name(topic) do
      :ok -> {:ok, topic}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_subscribe_payload(%{"topic" => _}) do
    {:error, "Topic must be a non-empty string"}
  end

  defp validate_subscribe_payload(_) do
    {:error, "Invalid subscribe format. Required: {\"topic\": \"topic_name\"}"}
  end

  defp validate_unsubscribe_payload(%{"topic" => topic}) when is_binary(topic) and topic != "" do
    case validate_topic_name(topic) do
      :ok -> {:ok, topic}
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_unsubscribe_payload(%{"topic" => _}) do
    {:error, "Topic must be a non-empty string"}
  end

  defp validate_unsubscribe_payload(_) do
    {:error, "Invalid unsubscribe format. Required: {\"topic\": \"topic_name\"}"}
  end

  defp validate_publish_payload(%{"topic" => topic, "message" => message})
       when is_binary(topic) and topic != "" do
    case validate_topic_name(topic) do
      :ok ->
        case validate_message(message) do
          :ok -> {:ok, {topic, message}}
          {:error, reason} -> {:error, reason}
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp validate_publish_payload(%{"topic" => _, "message" => _}) do
    {:error, "Topic must be a non-empty string"}
  end

  defp validate_publish_payload(_) do
    {:error, "Invalid publish format. Required: {\"topic\": \"topic_name\", \"message\": \"content\"}"}
  end

  defp validate_topic_name(topic) do
    # Basic topic name validation
    cond do
      String.length(topic) > 255 ->
        {:error, "Topic name too long (max 255 characters)"}

      not Regex.match?(~r/^[a-zA-Z0-9._-]+$/, topic) ->
        {:error, "Topic name contains invalid characters. Use only letters, numbers, dots, hyphens, and underscores"}

      true ->
        :ok
    end
  end

  defp validate_message(message) when is_binary(message) do
    if String.length(message) > 10_000 do
      {:error, "Message too long (max 10,000 characters)"}
    else
      :ok
    end
  end

  defp validate_message(message) when is_map(message) or is_list(message) do
    # Allow structured data
    :ok
  end

  defp validate_message(_) do
    {:error, "Message must be a string, map, or list"}
  end

  # Response building functions

  defp build_response(type, data \\ %{}, request_id \\ nil) do
    base_response = %{
      type: type,
      ts: DateTime.utc_now() |> DateTime.to_iso8601()
    }

    response = if request_id do
      Map.put(base_response, :request_id, request_id)
    else
      base_response
    end

    Map.merge(response, data)
  end

  defp build_ack_response(topic, data, request_id) do
    base_data = %{topic: topic}
    merged_data = Map.merge(base_data, data)
    build_response("ack", merged_data, request_id)
  end

  defp build_event_response(topic, message) do
    %{
      type: "event",
      topic: topic,
      message: message,
      ts: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  defp build_error_response(error_code, error_message, request_id \\ nil) do
    error_data = %{
      error: %{
        code: error_code,
        message: error_message
      }
    }

    build_response("error", error_data, request_id)
  end

  # Utility functions

  defp get_request_id(%{"request_id" => request_id}) when is_binary(request_id) do
    case validate_uuid(request_id) do
      true -> request_id
      false -> nil
    end
  end

  defp get_request_id(_), do: nil

  defp validate_uuid(uuid) when is_binary(uuid) do
    case UUID.info(uuid) do
      {:ok, _} -> true
      {:error, _} -> false
    end
  rescue
    _ ->
      # Fallback regex validation if UUID module not available
      Regex.match?(~r/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i, uuid)
  end

  defp validate_uuid(_), do: false

  defp generate_uuid do
    # Generate UUID v4
    case function_exported?(UUID, :uuid4, 0) do
      true -> UUID.uuid4()
      false -> Ecto.UUID.generate()
    end
  rescue
    _ ->
      # Fallback manual UUID generation
      :crypto.strong_rand_bytes(16)
      |> Base.encode16(case: :lower)
      |> String.replace(~r/(.{8})(.{4})(.{4})(.{4})(.{12})/, "\\1-\\2-\\3-\\4-\\5")
  end

  defp get_subscriber_count(topic) do
    # This should call your actual subscription manager
    case function_exported?(Pubsub.SubscriptionManager, :get_subscriber_count, 1) do
      true ->
        Pubsub.SubscriptionManager.get_subscriber_count(topic)
      false ->
        # Fallback if function doesn't exist
        0
    end
  rescue
    _ -> 0
  end
end
