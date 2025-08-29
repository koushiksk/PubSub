defmodule PubsubWeb.StatsController do
  use PubsubWeb, :controller

  @doc "Get comprehensive system statistics"
  def show(conn, _params) do
    stats = Pubsub.StatsCollector.get_stats()
    json(conn, stats)
  end
end
