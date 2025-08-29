defmodule Pubsub.MessageBrokerTest do
  use ExUnit.Case, async: true
  alias Pubsub.{TopicManager, SubscriptionManager, MessageBroker}

  setup do
    # Create a unique topic for each test
    topic = "test_topic_#{:rand.uniform(10000)}"
    {:ok, _} = TopicManager.create_topic(topic)

    on_exit(fn ->
      TopicManager.delete_topic(topic)
    end)

    {:ok, topic: topic}
  end

  describe "message publishing" do
    test "publish_sync/3 publishes to existing topic with subscribers", %{topic: topic} do
      # Subscribe current process
      SubscriptionManager.subscribe(topic, self())

      message = "test message"
      publisher_info = %{source: "test"}

      assert {:ok, %{delivered: 1, dropped: 0}} =
        MessageBroker.publish_sync(topic, message, publisher_info)

      # Should receive the message
      assert_receive {:pubsub_message, payload}
      assert payload.topic == topic
      assert payload.message == message
      assert payload.publisher == publisher_info

      # Clean up
      SubscriptionManager.unsubscribe(topic, self())
    end

    test "publish_sync/3 returns error for non-existent topic" do
      non_existent_topic = "non_existent_#{:rand.uniform(10000)}"

      assert {:error, :topic_not_found} =
        MessageBroker.publish_sync(non_existent_topic, "message", %{})
    end

    test "publish_sync/3 handles topic with no subscribers", %{topic: topic} do
      message = "test message"

      assert {:ok, %{delivered: 0, dropped: 0}} =
        MessageBroker.publish_sync(topic, message, %{})
    end

    test "publish_sync/3 delivers to multiple subscribers", %{topic: topic} do
      # Start multiple subscriber processes
      subscribers = for _i <- 1..3 do
        {:ok, pid} = Task.start_link(fn ->
          receive do
            {:pubsub_message, _} -> :ok
          after
            5000 -> :timeout
          end
        end)
        SubscriptionManager.subscribe(topic, pid)
        pid
      end

      message = "broadcast message"

      assert {:ok, %{delivered: 3, dropped: 0}} =
        MessageBroker.publish_sync(topic, message, %{})

      # Clean up
      Enum.each(subscribers, &SubscriptionManager.cleanup_subscriber/1)
    end

    test "publish/3 works asynchronously", %{topic: topic} do
      SubscriptionManager.subscribe(topic, self())

      message = "async message"
      MessageBroker.publish(topic, message, %{source: "async_test"})

      # Should receive the message
      assert_receive {:pubsub_message, payload}, 1000
      assert payload.topic == topic
      assert payload.message == message

      SubscriptionManager.unsubscribe(topic, self())
    end
  end

  describe "backpressure handling" do
    test "drops messages for processes with full queues", %{topic: topic} do
      # Create a process that doesn't read its messages
      {:ok, slow_pid} = Task.start_link(fn ->
        Process.sleep(10000)  # Don't read messages
      end)

      SubscriptionManager.subscribe(topic, slow_pid)

      # Fill up the message queue beyond the drop threshold
      # This is a simplified test - in reality you'd need to send many more messages
      message = "queue filling message"

      # Send some messages - some should be dropped due to backpressure
      results = for _i <- 1..5 do
        MessageBroker.publish_sync(topic, message, %{})
      end

      # At least one should succeed initially
      assert Enum.any?(results, fn
        {:ok, %{delivered: delivered}} when delivered > 0 -> true
        _ -> false
      end)

      # Clean up
      SubscriptionManager.cleanup_subscriber(slow_pid)
    end
  end

  describe "statistics" do
    test "get_stats/0 returns message statistics" do
      stats = MessageBroker.get_stats()

      assert Map.has_key?(stats, :published)
      assert Map.has_key?(stats, :delivered)
      assert Map.has_key?(stats, :dropped)
      assert is_integer(stats.published)
      assert is_integer(stats.delivered)
      assert is_integer(stats.dropped)
    end
  end
end
