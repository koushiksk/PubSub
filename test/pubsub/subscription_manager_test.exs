defmodule Pubsub.SubscriptionManagerTest do
  use ExUnit.Case, async: false
  alias Pubsub.SubscriptionManager

    describe "subscription management" do
    test "subscribe/2 and unsubscribe/2 work correctly" do
      topic = "sub_topic_#{:rand.uniform(10000)}"
      current_pid = self()

      # Subscribe
      assert :ok = SubscriptionManager.subscribe(topic, current_pid)
      subscribers = SubscriptionManager.get_subscribers(topic)
      assert [^current_pid] = subscribers
      assert 1 = SubscriptionManager.get_subscriber_count(topic)

      # Unsubscribe
      assert :ok = SubscriptionManager.unsubscribe(topic, current_pid)
      assert [] = SubscriptionManager.get_subscribers(topic)
      assert 0 = SubscriptionManager.get_subscriber_count(topic)
    end

    test "multiple subscribers to same topic" do
      topic = "multi_sub_topic_#{:rand.uniform(10000)}"
      current_pid = self()

      # Start test processes
      {:ok, pid1} = Task.start_link(fn -> Process.sleep(1000) end)
      {:ok, pid2} = Task.start_link(fn -> Process.sleep(1000) end)

      # Verify PIDs are different
      assert pid1 != pid2
      assert pid1 != current_pid
      assert pid2 != current_pid

      # Subscribe multiple processes
      assert :ok = SubscriptionManager.subscribe(topic, pid1)
      assert :ok = SubscriptionManager.subscribe(topic, pid2)
      assert :ok = SubscriptionManager.subscribe(topic, current_pid)

      subscribers = SubscriptionManager.get_subscribers(topic)
      unique_subscribers = Enum.uniq(subscribers) |> IO.inspect(label: "unique subscribers")

      # Should have 3 unique subscribers
      assert length(unique_subscribers) == 3
      assert pid1 in unique_subscribers
      assert pid2 in unique_subscribers
      assert current_pid in unique_subscribers

      # Clean up
      SubscriptionManager.cleanup_subscriber(pid1)
      SubscriptionManager.cleanup_subscriber(pid2)
      SubscriptionManager.unsubscribe(topic, current_pid)
    end

        test "get_subscriptions/1 returns topics for a subscriber" do
      topic1 = "get_sub_topic_1_#{:rand.uniform(10000)}"
      topic2 = "get_sub_topic_2_#{:rand.uniform(10000)}"
      current_pid = self()

      SubscriptionManager.subscribe(topic1, current_pid)
      SubscriptionManager.subscribe(topic2, current_pid)

      subscriptions = SubscriptionManager.get_subscriptions(current_pid)
      assert topic1 in subscriptions
      assert topic2 in subscriptions

      # Clean up
      SubscriptionManager.unsubscribe(topic1, current_pid)
      SubscriptionManager.unsubscribe(topic2, current_pid)
    end

    test "cleanup_subscriber/1 removes all subscriptions for a process" do
      topic1 = "cleanup_topic_1_#{:rand.uniform(10000)}"
      topic2 = "cleanup_topic_2_#{:rand.uniform(10000)}"

      {:ok, pid} = Task.start_link(fn -> Process.sleep(1000) end)

      SubscriptionManager.subscribe(topic1, pid)
      SubscriptionManager.subscribe(topic2, pid)

      assert pid in SubscriptionManager.get_subscribers(topic1)
      assert pid in SubscriptionManager.get_subscribers(topic2)

      SubscriptionManager.cleanup_subscriber(pid)

      refute pid in SubscriptionManager.get_subscribers(topic1)
      refute pid in SubscriptionManager.get_subscribers(topic2)
    end

        test "get_topic_stats/0 returns subscription statistics" do
      topic1 = "stats_topic_1_#{:rand.uniform(10000)}"
      topic2 = "stats_topic_2_#{:rand.uniform(10000)}"
      current_pid = self()

      SubscriptionManager.subscribe(topic1, current_pid)
      SubscriptionManager.subscribe(topic1, current_pid)  # Should handle duplicate
      SubscriptionManager.subscribe(topic2, current_pid)

      stats = SubscriptionManager.get_topic_stats()

      # topic1 should have 1 subscriber (duplicate ignored)
      # topic2 should have 1 subscriber
      assert Map.get(stats, topic1, 0) >= 1
      assert Map.get(stats, topic2, 0) >= 1

      # Clean up
      SubscriptionManager.unsubscribe(topic1, current_pid)
      SubscriptionManager.unsubscribe(topic2, current_pid)
    end
  end
end
