defmodule PubsubWeb.HealthController do
  use PubsubWeb, :controller

  def check(conn, _params) do
    health = Pubsub.StatsCollector.get_health()
    json(conn, health)
  end
end
