Of course. As a senior engineer, a clear, comprehensive, and scriptable test plan is essential for validating any API. Based on my analysis of your `PubsubWeb.Router`, I've prepared a complete testing guide.

### Analysis of `PubsubWeb.Router`

Your router defines two primary interfaces, each with a distinct purpose:

1.  **Browser Interface (`/`)**: This is a standard Phoenix pipeline for serving the main HTML page (`PageController, :home`). It's not the focus of our API testing but is the entry point for a web-based client. The commented-out `/ws` route is a good user-friendly touch for guiding users who mistakenly access the WebSocket endpoint via HTTP.
2.  **API Interface (`/api`)**: This is the core of your backend management and data injection system. It is a stateless, JSON-based REST API.
    *   **Observability (`/health`, `/stats`)**: Essential endpoints for monitoring and verifying the system's state.
    *   **Topic Management (`/topics`)**: A standard RESTful resource for creating, listing, viewing, and deleting topics. The `except` clause correctly indicates this is a pure API with no HTML form views.
    *   **Broadcasting (`/broadcast`)**: A critical action-oriented endpoint for injecting messages into the pub/sub system from external sources (e.g., other microservices, scripts).

The overall design is clean, conventional, and follows best practices by separating the concerns of the browser and API pipelines.

---

### Test Plan: `curl.md`

Below is the complete `curl.md` file. It provides a step-by-step guide to testing every aspect of your application's public-facing interfaces using the appropriate command-line tools.

---

# Pub/Sub System API Test Plan

This document provides a complete set of commands to perform end-to-end testing of the Pub/Sub system's REST and WebSocket APIs.

### Prerequisites

- The Phoenix server must be running on `http://localhost:4000`.
- The following command-line tools must be installed:
  - `curl`: For testing the REST API.
  - `websocat`: The "curl for WebSockets," for testing the real-time protocol.
  - `jq`: A command-line JSON processor, for pretty-printing responses.

---

## Part 1: REST API Testing (with `curl`)

These commands test the stateless management and broadcast endpoints. We will use a shell variable to store our topic name for convenience.

### Step 1: Health & Observability

First, let's verify that the system is running and check its initial state.

**A. Health Check**
```bash
curl http://localhost:4000/api/health | jq
```
*   **Expected Result:** An HTTP 200 OK status and a JSON body indicating a "healthy" status.

**B. Get System Statistics**
```bash
curl http://localhost:4000/api/stats | jq
```
*   **Expected Result:** An HTTP 200 OK status and a detailed JSON object containing system, topic, subscription, and message statistics.

### Step 2: Topic Lifecycle Management

We will now test the complete lifecycle of a topic: create, list, view, and delete.

**A. Create a New Topic**
We'll create a topic and store its name in a variable.

```bash
# Define a unique topic name
export TOPIC_NAME="financial-alerts-$(date +%s)"

# Send the create request
curl -X POST http://localhost:4000/api/topics \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$TOPIC_NAME\"}" | jq
```
*   **Expected Result:** A JSON response confirming the creation, e.g., `{"status":"created", "topic":"..."}`.

**B. List All Topics**
Verify that our new topic appears in the list of all topics.

```bash
curl http://localhost:4000/api/topics | jq
```
*   **Expected Result:** A JSON array of topic objects, which should include the `$TOPIC_NAME` we just created.

**C. Get Specific Topic Details**
Fetch the details for our specific topic.

```bash
curl http://localhost:4000/api/topics/$TOPIC_NAME | jq
```
*   **Expected Result:** A JSON object with the specific details for `$TOPIC_NAME`.

### Step 3: Broadcasting a Message

Now, we will use the REST API to publish a message. This simulates a backend service injecting data into the system.

```bash
curl -X POST http://localhost:4000/api/broadcast \
  -H "Content-Type: application/json" \
  -d "{\"topic\": \"$TOPIC_NAME\", \"message\": \"Market is showing high volatility.\"}"
```
*   **Expected Result:** A success response. We will verify the delivery in the WebSocket section.

### Step 4: Clean Up

Finally, we delete the topic to leave the system in a clean state.

```bash
curl -X DELETE http://localhost:4000/api/topics/$TOPIC_NAME
```
*   **Expected Result:** An HTTP 204 No Content status, indicating successful deletion.

---

## Part 2: WebSocket Protocol Testing (with `websocat`)

These commands test the real-time, stateful pub/sub functionality. This requires an interactive session.

### The Test Scenario

We will start a persistent subscriber in one terminal (`Terminal B`) and use another terminal (`Terminal A`) to send publish commands.

### Step 1: Start the Subscriber Client

*   In a new terminal window (**Terminal B**), start an interactive `websocat` session. This client will stay connected to listen for messages.

```bash
websocat --text ws://localhost:4000/ws/websocket
```
*   **Result:** The terminal will wait with a blinking cursor.

### Step 2: Join the Channel and `ping`

*   In **Terminal B**, paste the following single-line JSON and press Enter to join the main channel.

```json
{"topic":"pubsub", "event":"phx_join", "payload":{}, "ref":"1"}
```
*   You will see an `ok` reply. Now, test the connection with a `ping`. Paste the following and press Enter:

```json
{"topic":"pubsub", "event":"ping", "payload":{"echo": "hello"}, "ref":"2"}
```
*   **Expected Result:** You will get a `pong` reply, confirming the live connection is working.

### Step 3: `subscribe` to the Topic

*   Before subscribing, make sure the topic exists. In **Terminal A**, create a topic for this test:

```bash
export WS_TOPIC_NAME="realtime-metrics"
curl -X POST http://localhost:4000/api/topics -H "Content-Type: application/json" -d "{\"name\": \"$WS_TOPIC_NAME\"}"
```

*   Now, back in **Terminal B**, paste the following JSON to subscribe to the new topic:

```json
{"topic":"pubsub", "event":"subscribe", "payload":{"topic":"realtime-metrics"}, "ref":"3"}
```
*   **Expected Result:** You will get a `subscribed` reply. **Terminal B** is now actively listening for messages on the `realtime-metrics` topic.

### Step 4: `publish` a Message

*   In **Terminal B**, paste the following JSON to publish a message from the client itself:

```json
{"topic":"pubsub", "event":"publish", "payload":{"topic":"realtime-metrics", "message":{"cpu": 0.85, "mem": 0.65}}, "ref":"4"}
```
*   **Expected Result:** You will see two things appear almost instantly:
    1.  A `published` reply to your publish request.
    2.  A broadcasted `message` event, because your client is also a subscriber.

### Step 5: `unsubscribe` from the Topic

*   In **Terminal B**, paste the following JSON to stop listening to the topic:

```json
{"topic":"pubsub", "event":"unsubscribe", "payload":{"topic":"realtime-metrics"}, "ref":"5"}
```
*   **Expected Result:** You will get an `unsubscribed` reply.

### Step 6: Verify Unsubscription

*   To prove the unsubscription worked, go to **Terminal A** and publish another message to the topic:

```bash
curl -X POST http://localhost:4000/api/broadcast -H "Content-Type: application/json" -d "{\"topic\": \"$WS_TOPIC_NAME\", \"message\": \"This message should not be received.\"}"
```
*   **VERIFY:** Look at **Terminal B**. **No new message should appear.** This confirms the `unsubscribe` was successful.

### Step 7: Clean Up

*   In **Terminal A**, delete the topic.

```bash
curl -X DELETE http://localhost:4000/api/topics/$WS_TOPIC_NAME
```