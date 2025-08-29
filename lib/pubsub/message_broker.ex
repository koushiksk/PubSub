defmodule Pubsub.MessageBroker do
  @moduledoc """
  Handles message publishing and delivery with backpressure policies.
  """
  use GenServer
  require Logger

  @max_queue_size 1000
  @drop_threshold 0.8

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  @doc "Publish a message to a topic"
  def publish(topic_name, message, publisher_info \\ %{}) when is_binary(topic_name) do
    GenServer.cast(__MODULE__, {:publish, topic_name, message, publisher_info})
  end

  @doc "Publish a message synchronously with result"
  def publish_sync(topic_name, message, publisher_info \\ %{}) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:publish_sync, topic_name, message, publisher_info})
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # State: %{stats: %{published: 0, delivered: 0, dropped: 0}}
    state = %{
      stats: %{
        published: 0,
        delivered: 0,
        dropped: 0
      }
    }
    {:ok, state}
  end

  @impl true
  def handle_cast({:publish, topic_name, message, publisher_info}, state) do
    result = do_publish(topic_name, message, publisher_info)
    new_state = update_stats(state, result)
    {:noreply, new_state}
  end

  @impl true
  def handle_call({:publish_sync, topic_name, message, publisher_info}, _from, state) do
    result = do_publish(topic_name, message, publisher_info)
    new_state = update_stats(state, result)
    {:reply, result, new_state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  # Private Functions

  defp do_publish(topic_name, message, publisher_info) do
    # Check if topic exists
    case Pubsub.TopicManager.topic_exists?(topic_name) do
      false ->
        Logger.warning("Attempted to publish to non-existent topic: #{topic_name}")
        {:error, :topic_not_found}

      true ->
        subscribers = Pubsub.SubscriptionManager.get_subscribers(topic_name)

        if Enum.empty?(subscribers) do
          Logger.debug("No subscribers for topic: #{topic_name}")
          {:ok, %{delivered: 0, dropped: 0}}
        else
          deliver_message_to_subscribers(subscribers, topic_name, message, publisher_info)
        end
    end
  end

  defp deliver_message_to_subscribers(subscribers, topic_name, message, publisher_info) do
    message_payload = %{
      topic: topic_name,
      message: message,
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      publisher: publisher_info
    }

    results = Enum.map(subscribers, fn subscriber_pid ->
      deliver_to_subscriber(subscriber_pid, message_payload)
    end)

    delivered = Enum.count(results, fn result -> result == :ok end)
    dropped = Enum.count(results, fn result -> result == :dropped end)

    # Update topic message count
    Pubsub.TopicManager.increment_message_count(topic_name)

    Logger.debug("Published to topic #{topic_name}: #{delivered} delivered, #{dropped} dropped")

    {:ok, %{delivered: delivered, dropped: dropped}}
  end

  defp deliver_to_subscriber(subscriber_pid, message_payload) do
    if Process.alive?(subscriber_pid) do
      # Check subscriber's message queue length for backpressure
      case check_backpressure(subscriber_pid) do
        :ok ->
          send(subscriber_pid, {:pubsub_message, message_payload})
          :ok

        :drop ->
          Logger.warning("Dropping message for subscriber #{inspect(subscriber_pid)} due to backpressure")
          :dropped
      end
    else
      # Clean up dead subscriber
      Logger.debug("Cleaning up dead subscriber: #{inspect(subscriber_pid)}")
      Pubsub.SubscriptionManager.cleanup_subscriber(subscriber_pid)
      :dropped
    end
  end

  defp check_backpressure(pid) do
    case Process.info(pid, :message_queue_len) do
      {:message_queue_len, queue_len} when queue_len > @max_queue_size * @drop_threshold ->
        :drop

      {:message_queue_len, _} ->
        :ok

      nil ->
        :drop
    end
  end

  defp update_stats(state, result) do
    case result do
      {:ok, %{delivered: delivered, dropped: dropped}} ->
        new_stats = state.stats
        |> Map.update!(:published, &(&1 + 1))
        |> Map.update!(:delivered, &(&1 + delivered))
        |> Map.update!(:dropped, &(&1 + dropped))

        Map.put(state, :stats, new_stats)

      {:error, _} ->
        state
    end
  end

  @doc "Get publishing statistics"
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end
end
