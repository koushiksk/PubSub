defmodule Pubsub.StatsCollector do
  @moduledoc """
  Collects and provides system-wide statistics for the Pub/Sub system.
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, :ok, [{:name, __MODULE__} | opts])
  end

  @doc "Get comprehensive system statistics"
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc "Get health status"
  def get_health do
    GenServer.call(__MODULE__, :get_health)
  end

  # Server Callbacks

  @impl true
  def init(:ok) do
    state = %{
      started_at: DateTime.utc_now()
    }
    {:ok, state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = collect_system_stats(state)
    {:reply, stats, state}
  end

  @impl true
  def handle_call(:get_health, _from, state) do
    health = %{
      status: "healthy",
      uptime_seconds: DateTime.diff(DateTime.utc_now(), state.started_at),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      service: "pubsub-system"
    }
    {:reply, health, state}
  end

  # Private Functions

  defp collect_system_stats(state) do
    # Get topic statistics
    topics = Pubsub.TopicManager.list_topics()
    topic_count = length(topics)

    # Get subscription statistics
    topic_stats = Pubsub.SubscriptionManager.get_topic_stats()
    total_subscriptions = Map.values(topic_stats) |> Enum.sum()

    # Get message broker statistics
    broker_stats = Pubsub.MessageBroker.get_stats()

    # Get process statistics
    process_stats = get_process_stats()

    # Calculate uptime
    uptime_seconds = DateTime.diff(DateTime.utc_now(), state.started_at)

    %{
      system: %{
        uptime_seconds: uptime_seconds,
        started_at: DateTime.to_iso8601(state.started_at),
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      },
      topics: %{
        total_count: topic_count,
        details: topics
      },
      subscriptions: %{
        total_count: total_subscriptions,
        by_topic: topic_stats
      },
      messages: broker_stats,
      processes: process_stats
    }
  end

  defp get_process_stats do
    %{
      total_processes: :erlang.system_info(:process_count),
      memory_usage: %{
        total: :erlang.memory(:total),
        processes: :erlang.memory(:processes),
        system: :erlang.memory(:system),
        atom: :erlang.memory(:atom),
        binary: :erlang.memory(:binary),
        ets: :erlang.memory(:ets)
      },
      schedulers: %{
        online: :erlang.system_info(:schedulers_online),
        total: :erlang.system_info(:schedulers)
      }
    }
  end
end
