defmodule Pubsub.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PubsubWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:pubsub, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Pubsub.PubSub},
      # Pub/Sub System Registry
      {Registry, keys: :duplicate, name: Pubsub.SubscriptionRegistry},
      # Pub/Sub System Components
      Pubsub.TopicManager,
      Pubsub.SubscriptionManager,
      Pubsub.MessageBroker,
      Pubsub.StatsCollector,
      # Start to serve requests, typically the last entry
      PubsubWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Pubsub.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PubsubWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
