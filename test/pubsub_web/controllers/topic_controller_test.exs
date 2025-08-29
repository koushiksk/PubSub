defmodule PubsubWeb.TopicControllerTest do
  use PubsubWeb.ConnCase, async: true
  alias Pubsub.TopicManager

  describe "POST /api/topics" do
    test "creates a new topic", %{conn: conn} do
      topic_name = "api_test_topic_#{:rand.uniform(10000)}"

      conn = post(conn, ~p"/api/topics", %{"name" => topic_name})

      assert json_response(conn, 201)["status"] == "created"
      assert json_response(conn, 201)["topic"] == topic_name
      assert TopicManager.topic_exists?(topic_name)

      # Clean up
      TopicManager.delete_topic(topic_name)
    end

    test "returns error for duplicate topic", %{conn: conn} do
      topic_name = "duplicate_topic_#{:rand.uniform(10000)}"

      # Create topic first
      {:ok, _} = TopicManager.create_topic(topic_name)

      conn = post(conn, ~p"/api/topics", %{"name" => topic_name})

      assert json_response(conn, 409)["error"] == "Topic already exists"

      # Clean up
      TopicManager.delete_topic(topic_name)
    end

    test "returns error for missing name parameter", %{conn: conn} do
      conn = post(conn, ~p"/api/topics", %{})

      assert json_response(conn, 400)["error"] == "Missing required parameter"
      assert json_response(conn, 400)["required"] == "name"
    end
  end

  describe "DELETE /api/topics/:id" do
    test "deletes an existing topic", %{conn: conn} do
      topic_name = "deletable_api_topic_#{:rand.uniform(10000)}"

      # Create topic first
      {:ok, _} = TopicManager.create_topic(topic_name)

      conn = delete(conn, ~p"/api/topics/#{topic_name}")

      assert json_response(conn, 200)["status"] == "deleted"
      assert json_response(conn, 200)["topic"] == topic_name
      refute TopicManager.topic_exists?(topic_name)
    end

    test "returns error for non-existent topic", %{conn: conn} do
      topic_name = "non_existent_api_topic_#{:rand.uniform(10000)}"

      conn = delete(conn, ~p"/api/topics/#{topic_name}")

      assert json_response(conn, 404)["error"] == "Topic not found"
    end
  end

  describe "GET /api/topics" do
    test "lists all topics", %{conn: conn} do
      topic1 = "list_api_topic_1_#{:rand.uniform(10000)}"
      topic2 = "list_api_topic_2_#{:rand.uniform(10000)}"

      # Create topics
      {:ok, _} = TopicManager.create_topic(topic1)
      {:ok, _} = TopicManager.create_topic(topic2)

      conn = get(conn, ~p"/api/topics")
      response = json_response(conn, 200)

      assert Map.has_key?(response, "topics")
      assert Map.has_key?(response, "count")
      assert is_list(response["topics"])
      assert is_integer(response["count"])

      topic_names = Enum.map(response["topics"], & &1["name"])
      assert topic1 in topic_names
      assert topic2 in topic_names

      # Clean up
      TopicManager.delete_topic(topic1)
      TopicManager.delete_topic(topic2)
    end
  end

  describe "GET /api/topics/:id" do
    test "returns topic details", %{conn: conn} do
      topic_name = "detail_api_topic_#{:rand.uniform(10000)}"

      # Create topic
      {:ok, _} = TopicManager.create_topic(topic_name)

      conn = get(conn, ~p"/api/topics/#{topic_name}")
      response = json_response(conn, 200)

      assert response["name"] == topic_name
      assert Map.has_key?(response, "created_at")
      assert Map.has_key?(response, "message_count")
      assert Map.has_key?(response, "subscriber_count")
      assert response["message_count"] == 0
      assert response["subscriber_count"] == 0

      # Clean up
      TopicManager.delete_topic(topic_name)
    end

    test "returns error for non-existent topic", %{conn: conn} do
      topic_name = "non_existent_detail_topic_#{:rand.uniform(10000)}"

      conn = get(conn, ~p"/api/topics/#{topic_name}")

      assert json_response(conn, 404)["error"] == "Topic not found"
    end
  end
end
