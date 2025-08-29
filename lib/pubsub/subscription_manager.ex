defmodule Pubsub.SubscriptionManager do
  @moduledoc """
  Manages subscriber registrations using GenServer state.
  Handles subscription lifecycle and cleanup.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  @doc "Subscribe a process to a topic"
  def subscribe(topic_name, subscriber_pid \\ self()) when is_binary(topic_name) and is_pid(subscriber_pid) do
    GenServer.call(__MODULE__, {:subscribe, topic_name, subscriber_pid})
  end

  @doc "Unsubscribe a process from a topic"
  def unsubscribe(topic_name, subscriber_pid \\ self()) when is_binary(topic_name) and is_pid(subscriber_pid) do
    GenServer.call(__MODULE__, {:unsubscribe, topic_name, subscriber_pid})
  end

  @doc "Get all subscribers for a topic"
  def get_subscribers(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:get_subscribers, topic_name})
  end

  @doc "Get subscriber count for a topic"
  def get_subscriber_count(topic_name) when is_binary(topic_name) do
    GenServer.call(__MODULE__, {:get_subscriber_count, topic_name})
  end

  @doc "Get all topics a process is subscribed to"
  def get_subscriptions(subscriber_pid \\ self()) when is_pid(subscriber_pid) do
    GenServer.call(__MODULE__, {:get_subscriptions, subscriber_pid})
  end

  @doc "Clean up all subscriptions for a topic"
  def cleanup_topic(topic_name) when is_binary(topic_name) do
    GenServer.cast(__MODULE__, {:cleanup_topic, topic_name})
  end

  @doc "Clean up all subscriptions for a process"
  def cleanup_subscriber(subscriber_pid) when is_pid(subscriber_pid) do
    GenServer.call(__MODULE__, {:cleanup_subscriber, subscriber_pid})
  end

  @doc "Get all active topics with subscriber counts"
  def get_topic_stats do
    GenServer.call(__MODULE__, :get_topic_stats)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    # State: %{topic_name => MapSet.new([pid1, pid2, ...])}
    {:ok, %{}}
  end

  @impl true
  def handle_call({:subscribe, topic_name, subscriber_pid}, _from, state) do
    current_subscribers = Map.get(state, topic_name, MapSet.new())

    if MapSet.member?(current_subscribers, subscriber_pid) do
      Logger.debug("#{inspect(subscriber_pid)} already subscribed to topic: #{topic_name}")
      {:reply, :ok, state}
    else
      new_subscribers = MapSet.put(current_subscribers, subscriber_pid)
      new_state = Map.put(state, topic_name, new_subscribers)
      Logger.debug("Subscribed #{inspect(subscriber_pid)} to topic: #{topic_name}")
      {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:unsubscribe, topic_name, subscriber_pid}, _from, state) do
    case Map.get(state, topic_name) do
      nil ->
        Logger.debug("#{inspect(subscriber_pid)} was not subscribed to topic: #{topic_name}")
        {:reply, :ok, state}

      subscribers ->
        new_subscribers = MapSet.delete(subscribers, subscriber_pid)
        new_state = if MapSet.size(new_subscribers) == 0 do
          Map.delete(state, topic_name)
        else
          Map.put(state, topic_name, new_subscribers)
        end
        Logger.debug("Unsubscribed #{inspect(subscriber_pid)} from topic: #{topic_name}")
        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call({:get_subscribers, topic_name}, _from, state) do
    subscribers =
      state
      |> Map.get(topic_name, MapSet.new())
      |> MapSet.to_list()

    {:reply, subscribers, state}
  end

  @impl true
  def handle_call({:get_subscriber_count, topic_name}, _from, state) do
    count =
      state
      |> Map.get(topic_name, MapSet.new())
      |> MapSet.size()

    {:reply, count, state}
  end

  @impl true
  def handle_call({:get_subscriptions, subscriber_pid}, _from, state) do
    topics =
      state
      |> Enum.filter(fn {_topic, subscribers} -> MapSet.member?(subscribers, subscriber_pid) end)
      |> Enum.map(fn {topic, _subscribers} -> topic end)

    {:reply, topics, state}
  end

  @impl true
  def handle_call({:cleanup_subscriber, subscriber_pid}, _from, state) do
    new_state =
      state
      |> Enum.map(fn {topic, subscribers} ->
        {topic, MapSet.delete(subscribers, subscriber_pid)}
      end)
      |> Enum.filter(fn {_topic, subscribers} -> MapSet.size(subscribers) > 0 end)
      |> Enum.into(%{})

    Logger.debug("Cleaned up subscriptions for #{inspect(subscriber_pid)}")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_topic_stats, _from, state) do
    stats =
      state
      |> Enum.map(fn {topic, subscribers} -> {topic, MapSet.size(subscribers)} end)
      |> Enum.into(%{})

    {:reply, stats, state}
  end

  @impl true
  def handle_cast({:cleanup_topic, topic_name}, state) do
    new_state = Map.delete(state, topic_name)
    Logger.info("Cleaned up all subscriptions for topic: #{topic_name}")
    {:noreply, new_state}
  end
end
