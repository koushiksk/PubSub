defmodule PubsubWeb.HealthControllerTest do
  use PubsubWeb.ConnCase, async: true

  describe "GET /api/health" do
    test "returns health status", %{conn: conn} do
      conn = get(conn, ~p"/api/health")
      response = json_response(conn, 200)

      assert response["status"] == "healthy"
      assert Map.has_key?(response, "uptime_seconds")
      assert Map.has_key?(response, "timestamp")
      assert response["service"] == "pubsub-system"
      assert is_integer(response["uptime_seconds"])
      assert response["uptime_seconds"] >= 0
    end
  end
end
