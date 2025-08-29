defmodule Pubsub.TopicManagerTest do
  use ExUnit.Case, async: true
  alias Pubsub.TopicManager

  describe "topic management" do
    test "create_topic/1 creates a new topic" do
      topic_name = "test_topic_#{:rand.uniform(10000)}"

      assert {:ok, ^topic_name} = TopicManager.create_topic(topic_name)
      assert TopicManager.topic_exists?(topic_name)
    end

    test "create_topic/1 returns error for existing topic" do
      topic_name = "existing_topic_#{:rand.uniform(10000)}"

      {:ok, _} = TopicManager.create_topic(topic_name)
      assert {:error, :topic_already_exists} = TopicManager.create_topic(topic_name)
    end

    test "delete_topic/1 removes an existing topic" do
      topic_name = "deletable_topic_#{:rand.uniform(10000)}"

      {:ok, _} = TopicManager.create_topic(topic_name)
      assert {:ok, ^topic_name} = TopicManager.delete_topic(topic_name)
      refute TopicManager.topic_exists?(topic_name)
    end

    test "delete_topic/1 returns error for non-existent topic" do
      topic_name = "non_existent_topic_#{:rand.uniform(10000)}"

      assert {:error, :topic_not_found} = TopicManager.delete_topic(topic_name)
    end

    test "list_topics/0 returns all topics" do
      topic1 = "list_topic_1_#{:rand.uniform(10000)}"
      topic2 = "list_topic_2_#{:rand.uniform(10000)}"

      {:ok, _} = TopicManager.create_topic(topic1)
      {:ok, _} = TopicManager.create_topic(topic2)

      topics = TopicManager.list_topics()
      topic_names = Enum.map(topics, & &1.name)

      assert topic1 in topic_names
      assert topic2 in topic_names
    end

    test "get_topic_info/1 returns topic information" do
      topic_name = "info_topic_#{:rand.uniform(10000)}"

      {:ok, _} = TopicManager.create_topic(topic_name)
      assert {:ok, info} = TopicManager.get_topic_info(topic_name)

      assert Map.has_key?(info, :created_at)
      assert Map.has_key?(info, :message_count)
      assert info.message_count == 0
    end

    test "increment_message_count/1 updates message count" do
      topic_name = "count_topic_#{:rand.uniform(10000)}"

      {:ok, _} = TopicManager.create_topic(topic_name)
      TopicManager.increment_message_count(topic_name)

      # Give the cast time to process
      :timer.sleep(10)

      {:ok, info} = TopicManager.get_topic_info(topic_name)
      assert info.message_count == 1
    end
  end
end
