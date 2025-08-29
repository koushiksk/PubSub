# Phoenix In-Memory Pub/Sub System

A high-performance, in-memory Pub/Sub system built with Elixir and Phoenix, supporting both WebSocket and REST API interfaces.

## 🏗️ System Architecture

### Core Components

- **TopicManager**: GenServer managing topic lifecycle (create, delete, metadata)
- **SubscriptionManager**: Registry-based subscriber tracking with automatic cleanup
- **MessageBroker**: Handles message publishing, delivery, and backpressure policies
- **StatsCollector**: Real-time system metrics and observability

### Design Principles

- **In-Memory Only**: No external dependencies (Redis, Kafka, etc.)
- **Concurrency-Safe**: Uses Elixir's Actor model for race-condition-free operations
- **Backpressure Handling**: Automatic message dropping for slow consumers
- **Auto Cleanup**: Subscriber cleanup on disconnection
- **High Performance**: Built on Elixir/OTP for massive concurrency

## 🚀 Quick Start

### Prerequisites

- Erlang/OTP 26+
- Elixir 1.16+
- Node.js (for asset compilation)

### Running Locally

```bash
# Clone and setup
git clone https://github.com/koushiksk/PubSub.git
cd pubsub

# Install dependencies
mix deps.get

# Start the server
mix phx.server
```

The server will be available at `http://localhost:4000`

### Running with Docker

```bash
# Build and run
docker build -t pubsub .
docker run -p 4000:4000 pubsub

# Or use docker-compose
docker-compose up
```

### Scaling Considerations

- **Horizontal**: Multiple instances with load balancer
- **Vertical**: Single instance can handle 10K+ connections
- **Memory**: ~1MB per 1000 active subscriptions
- **CPU**: Scales linearly with message throughput

## 🔍 Troubleshooting

### Common Issues

1. **WebSocket Connection Fails**
   - Check if server is running on correct port
   - Verify WebSocket URL (ws://, not http://)

2. **Messages Not Delivered**
   - Ensure topic exists before subscribing
   - Check if subscriber process is alive
   - Monitor dropped message count in stats

3. **High Memory Usage**
   - Check for dead subscriber cleanup
   - Monitor message queue lengths
   - Review subscription patterns

---