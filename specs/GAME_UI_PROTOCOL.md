# Hive Game UI Protocol Specification

This document defines the interface for building a 3D "God Mode" visualization for the Hive autonomous software factory.

## Connection

*   **URL:** `ws://localhost:4000/socket/websocket`
*   **Protocol:** Phoenix Channels (V2 JSON)
*   **Topic:** `game:control`

To connect from a non-Phoenix client (e.g., Unity/C#, Godot/GDScript), you need a Phoenix Channel client library or implement the handshake manually.

### Handshake (Raw Websocket)

1.  Connect to `ws://localhost:4000/socket/websocket`.
2.  Send Join Message:
    ```json
    ["1", "1", "game:control", "phx_join", {}]
    ```
3.  Receive Reply (Success):
    ```json
    ["1", "1", "game:control", "phx_reply", {"response": {}, "status": "ok"}]
    ```

---

## Outbound Events (Hive -> Game)

The Hive pushes these events to the client.

### 1. `world_state`
Sent immediately upon joining. Represents the full snapshot of the factory.

**Payload Schema:**
```json
{
  "quests": [
    {
      "id": "quest-123",
      "name": "Refactor Auth",
      "status": "active", // pending, active, completed, failed
      "current_phase": "implementation",
      "comb_id": "comb-main"
    }
  ],
  "bees": [
    {
      "id": "swift-scout-ab12",
      "name": "Swift Scout",
      "status": "working", // starting, working, idle, stopped
      "job_id": "job-456",
      "context_percentage": 0.45 // 0.0 to 1.0 (context window usage)
    }
  ],
  "combs": [
    {
      "id": "comb-main",
      "name": "Main Repository",
      "path": "/data/hive/worktrees/main"
    }
  ]
}
```

### 2. `hive_event`
Real-time telemetry updates. Use these to animate the 3D world (e.g., spawn a bee model, flash a quest node).

**Payload Schema:**
```json
{
  "type": "string", // Event name (see Event Types below)
  "timestamp": 1708456000123, // Unix ms
  "data": { ... } // Dynamic metadata based on event type
}
```

**Event Types:**

| Event Type | Data Fields | Description | Visual Cue |
| :--- | :--- | :--- | :--- |
| `hive.bee.spawned` | `bee_id`, `job_id`, `comb_id` | A new bee has entered the factory. | Spawn Bee model at Comb location. |
| `hive.job.started` | `job_id`, `quest_id` | A bee started working on a job. | Draw line between Bee and Quest. |
| `hive.job.completed` | `job_id` | Work finished. | Bee deposits payload at Quest, turns green. |
| `hive.job.failed` | `job_id` | Work failed. | Bee turns red, emits smoke/particles. |
| `hive.quest.phase_transition` | `quest_id`, `from`, `to` | Quest moved to next phase. | Quest node pulses/changes color. |
| `hive.alert.raised` | `type`, `message` | System alert. | Flash screen/UI warning. |

---

## Inbound Commands (Game -> Hive)

The game client can send these messages to control the factory.

### 1. `spawn_quest`
Create a new work order.

**Message:**
```json
["ref", "topic", "spawn_quest", {
  "goal": "Build a login page",
  "comb_id": "comb-main" // Optional, defaults to first available
}]
```

**Response:**
```json
{"status": "ok", "response": {"quest_id": "quest-789"}}
```

### 2. `emergency_stop`
Kill all active bees immediately.

**Message:**
```json
["ref", "topic", "emergency_stop", {}]
```

**Response:**
```json
{"status": "ok", "response": "ok"}
```

---

## 3D Visualization Guidelines

*   **Combs:** Represent as hexagonal landing pads.
*   **Quests:** Represent as large floating crystals or monoliths above the pads. Color code by phase (Research=Blue, Implementation=Orange, Validation=Purple).
*   **Bees:** Represent as drones flying between the Hive center (or Comb) and the Quest monoliths.
*   **Budget:** Display a "Burn Rate" meter in the HUD.
