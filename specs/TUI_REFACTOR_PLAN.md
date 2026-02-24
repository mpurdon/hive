# Ratatouille TUI Refactor Plan

This document outlines the strategy for rebuilding the Hive TUI using the `ratatouille` library.

## Goals
- **Stability:** Use Ratatouille's robust layout engine to eliminate scrolling/wrapping bugs.
- **Maintainability:** Separation of concerns using Model-View-Update (MVU) architecture.
- **Aesthetics:** Clean, bordered panels with consistent styling.

## Architecture

The TUI will be rebuilt in `lib/hive/tui/` with the following structure:

### 1. `Hive.TUI.App`
The entry point application module implementing `Ratatouille.App`.
- **Model:** Holds the state (`chat`, `activity`, `input`).
- **Update:** Handles events (`:resize`, keys, PubSub messages).
- **View:** Defines the root layout using `<view>`, `<row>`, `<column>`.

### 2. `Hive.TUI.Constants`
- Define themes (colors), dimensions, and layout constants.

### 3. Components (Views)
Ratatouille uses a declarative view tree. We will define helper functions to render specific sections:

- **`Hive.TUI.Views.Chat`**
  - Renders the chat history.
  - Uses `<viewport>` for scrolling.
  - Renders styled text for User/Assistant/System messages.

- **`Hive.TUI.Views.Activity`**
  - Renders the "Activity" panel.
  - Sections:
    - **Factory Status:** Health checks, global metrics.
    - **Bees:** Table of active bees.
    - **Quests:** List of active quests.

- **`Hive.TUI.Views.Input`**
  - Renders the input bar at the bottom.
  - Handles the prompt character (`> `, `/ `, etc.).
  - Shows the current input text.

### 4. Logic & State Management
We will port the existing logic from the deleted components into new context modules:
- `Hive.TUI.Context.Chat` (Manages history buffer)
- `Hive.TUI.Context.Input` (Manages text editing, history, cursor)
- `Hive.TUI.Context.Activity` (Manages stats snapshots)

## Layout Structure

```
+-------------------------------------------------------+
|  Chat (Flex 2)            |  Activity (Flex 1)        |
|                           |                           |
|  [System] ...             |  Factory: OK              |
|  > User msg               |                           |
|                           |  Bees (2)                 |
|                           |  - Bee 1 [working]        |
|                           |                           |
+---------------------------+---------------------------+
|  Input                                                |
|  > Type here...                                       |
+-------------------------------------------------------+
|  Status Bar: 0 bees | $0.00                           |
+-------------------------------------------------------+
```

## Implementation Steps

1.  **Dependencies:** Verify `ratatouille` installs and compiles.
2.  **Scaffolding:** Create `Hive.TUI.App` with a basic "Hello World" view.
3.  **Input:** Implement the Input view and keyboard handling (typing, backspace, enter).
4.  **Chat:** Implement the Chat view and connect it to `handle_submit`.
5.  **Activity:** Implement the Activity view and connect it to PubSub.
6.  **Polish:** Refine colors, borders, and scrolling behavior.

## Key Changes from Legacy
- No manual string padding (`String.duplicate(" ", n)`).
- No manual border construction (`┌──┐`).
- Use `<panel title="...">` provided by Ratatouille (or build a standard bordered view helper).
