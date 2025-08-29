defmodule PubsubWeb.TopicController do
  use PubsubWeb, :controller
  require Logger

  @doc "Create a new topic"
  def create(conn, %{"name" => topic_name}) when is_binary(topic_name) do
    case Pubsub.TopicManager.create_topic(topic_name) do
      {:ok, topic_name} ->
        Logger.info("Created topic via REST API: #{topic_name}")

        conn
        |> put_status(:created)
        |> json(%{
          status: "created",
          topic: topic_name,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :topic_already_exists} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          error: "Topic already exists",
          topic: topic_name
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{
      error: "Missing required parameter",
      required: "name"
    })
  end

  @doc "Delete a topic"
  def delete(conn, %{"id" => topic_name}) when is_binary(topic_name) do
    case Pubsub.TopicManager.delete_topic(topic_name) do
      {:ok, topic_name} ->
        Logger.info("Deleted topic via REST API: #{topic_name}")

        json(conn, %{
          status: "deleted",
          topic: topic_name,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        })

      {:error, :topic_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Topic not found",
          topic: topic_name
        })
    end
  end

  @doc "List all topics"
  def index(conn, _params) do
    topics = Pubsub.TopicManager.list_topics()

    json(conn, %{
      topics: topics,
      count: length(topics),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
    })
  end

  @doc "Get topic details"
  def show(conn, %{"id" => topic_name}) when is_binary(topic_name) do
    case Pubsub.TopicManager.get_topic_info(topic_name) do
      {:ok, topic_info} ->
        subscriber_count = Pubsub.SubscriptionManager.get_subscriber_count(topic_name)

        response = topic_info
        |> Map.put(:name, topic_name)
        |> Map.put(:subscriber_count, subscriber_count)

        json(conn, response)

      {:error, :topic_not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          error: "Topic not found",
          topic: topic_name
        })
    end
  end
end
