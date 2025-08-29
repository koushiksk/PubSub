defmodule Pubsub.TopicManager do
  @moduledoc """
  GenServer responsible for managing topic lifecycle.
  Tracks topic creation, deletion, and metadata.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  @doc "Create a new topic"
  def create_topic(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:create_topic, topic_name})
  end

  @doc "Delete a topic and clean up all subscriptions"
  def delete_topic(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:delete_topic, topic_name})
  end

  @doc "List all active topics"
  def list_topics do
    GenServer.call(__MODULE__, :list_topics)
  end

  @doc "Check if topic exists"
  def topic_exists?(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:topic_exists, topic_name})
  end

  @doc "Get topic info"
  def get_topic_info(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:get_topic_info, topic_name})
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # State: %{topic_name => %{created_at: DateTime, message_count: integer}}
    {:ok, %{}}
  end

  @impl true
  def handle_call({:create_topic, topic_name}, _from, state) do
    case Map.get(state, topic_name) do
      nil ->
        topic_info = %{
          created_at: DateTime.utc_now(),
          message_count: 0
        }
        new_state = Map.put(state, topic_name, topic_info)
        Logger.info("Created topic: #{topic_name}")
        {:reply, {:ok, topic_name}, new_state}

      _existing ->
        {:reply, {:error, :topic_already_exists}, state}
    end
  end

  @impl true
  def handle_call({:delete_topic, topic_name}, _from, state) do
    case Map.get(state, topic_name) do
      nil ->
        {:reply, {:error, :topic_not_found}, state}

      _topic_info ->
        # Notify subscription manager to clean up subscriptions
        Pubsub.SubscriptionManager.cleanup_topic(topic_name)
        new_state = Map.delete(state, topic_name)
        Logger.info("Deleted topic: #{topic_name}")
        {:reply, {:ok, topic_name}, new_state}
    end
  end

  @impl true
  def handle_call(:list_topics, _from, state) do
    topics = Enum.map(state, fn {name, info} ->
      subscriber_count = Pubsub.SubscriptionManager.get_subscriber_count(name)
      Map.put(info, :name, name)
      |> Map.put(:subscriber_count, subscriber_count)
    end)
    {:reply, topics, state}
  end

  @impl true
  def handle_call({:topic_exists, topic_name}, _from, state) do
    exists = Map.has_key?(state, topic_name)
    {:reply, exists, state}
  end

  @impl true
  def handle_call({:get_topic_info, topic_name}, _from, state) do
    case Map.get(state, topic_name) do
      nil -> {:reply, {:error, :topic_not_found}, state}
      info -> {:reply, {:ok, info}, state}
    end
  end

  @impl true
  def handle_cast({:increment_message_count, topic_name}, state) do
    case Map.get(state, topic_name) do
      nil ->
        {:noreply, state}

      topic_info ->
        updated_info = Map.update!(topic_info, :message_count, &(&1 + 1))
        new_state = Map.put(state, topic_name, updated_info)
        {:noreply, new_state}
    end
  end

  @doc "Increment message count for a topic"
  def increment_message_count(topic_name) do
    GenServer.cast(__MODULE__, {:increment_message_count, topic_name})
  end
end
