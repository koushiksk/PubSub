defmodule PubsubWeb.StatsControllerTest do
  use PubsubWeb.ConnCase, async: true

  describe "GET /api/stats" do
    test "returns comprehensive system statistics", %{conn: conn} do
      conn = get(conn, ~p"/api/stats")
      response = json_response(conn, 200)

      # Check top-level structure
      assert Map.has_key?(response, "system")
      assert Map.has_key?(response, "topics")
      assert Map.has_key?(response, "subscriptions")
      assert Map.has_key?(response, "messages")
      assert Map.has_key?(response, "processes")

      # Check system stats
      system = response["system"]
      assert Map.has_key?(system, "uptime_seconds")
      assert Map.has_key?(system, "started_at")
      assert Map.has_key?(system, "timestamp")
      assert is_integer(system["uptime_seconds"])

      # Check topics stats
      topics = response["topics"]
      assert Map.has_key?(topics, "total_count")
      assert Map.has_key?(topics, "details")
      assert is_integer(topics["total_count"])
      assert is_list(topics["details"])

      # Check subscriptions stats
      subscriptions = response["subscriptions"]
      assert Map.has_key?(subscriptions, "total_count")
      assert Map.has_key?(subscriptions, "by_topic")
      assert is_integer(subscriptions["total_count"])
      assert is_map(subscriptions["by_topic"])

      # Check messages stats
      messages = response["messages"]
      assert Map.has_key?(messages, "published")
      assert Map.has_key?(messages, "delivered")
      assert Map.has_key?(messages, "dropped")
      assert is_integer(messages["published"])
      assert is_integer(messages["delivered"])
      assert is_integer(messages["dropped"])

      # Check processes stats
      processes = response["processes"]
      assert Map.has_key?(processes, "total_processes")
      assert Map.has_key?(processes, "memory_usage")
      assert Map.has_key?(processes, "schedulers")
      assert is_integer(processes["total_processes"])
      assert is_map(processes["memory_usage"])
      assert is_map(processes["schedulers"])
    end
  end
end
