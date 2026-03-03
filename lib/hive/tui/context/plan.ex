defmodule Hive.TUI.Context.Plan do
  @moduledoc """
  Manages plan state for the TUI plan review flow.

  When the LLM generates a plan, it's loaded here as a set of sections
  that the user can navigate, accept, reject, or ask questions about.
  """

  defstruct quest_id: nil,
            goal: nil,
            sections: [],
            selected: 0,
            mode: :hidden

  @type section :: %{
          title: String.t(),
          description: String.t(),
          tasks: [map()],
          status: :pending | :accepted | :rejected
        }

  @type t :: %__MODULE__{
          quest_id: String.t() | nil,
          goal: String.t() | nil,
          sections: [section()],
          selected: non_neg_integer(),
          mode: :hidden | :reviewing | :confirmed | :rejected
        }

  def new, do: %__MODULE__{}

  @doc "Load a plan from an LLM response into the context."
  def load_plan(state, %{} = plan) do
    quest_id = plan[:quest_id] || plan["quest_id"]
    goal = plan[:goal] || plan["goal"]
    tasks = plan[:tasks] || plan["tasks"] || []

    sections =
      tasks
      |> Enum.with_index(1)
      |> Enum.map(fn {task, idx} ->
        %{
          title: "#{idx}. #{task["title"] || task[:title] || "Task #{idx}"}",
          description: task["description"] || task[:description] || "",
          tasks: [task],
          target_files: task["target_files"] || task[:target_files] || [],
          model: task["model_recommendation"] || task[:model_recommendation],
          status: :pending
        }
      end)

    %{state |
      quest_id: quest_id,
      goal: goal,
      sections: sections,
      selected: 0,
      mode: :reviewing
    }
  end

  @doc "Select the next section."
  def select_next(%{sections: sections, selected: sel} = state) do
    %{state | selected: min(sel + 1, length(sections) - 1)}
  end

  @doc "Select the previous section."
  def select_prev(%{selected: sel} = state) do
    %{state | selected: max(sel - 1, 0)}
  end

  @doc "Accept the currently selected section."
  def accept_section(%{sections: sections, selected: sel} = state) do
    sections = List.update_at(sections, sel, &Map.put(&1, :status, :accepted))
    %{state | sections: sections}
  end

  @doc "Reject the currently selected section."
  def reject_section(%{sections: sections, selected: sel} = state) do
    sections = List.update_at(sections, sel, &Map.put(&1, :status, :rejected))
    %{state | sections: sections}
  end

  @doc "Accept all remaining pending sections."
  def accept_all(%{sections: sections} = state) do
    sections =
      Enum.map(sections, fn s ->
        if s.status == :pending, do: Map.put(s, :status, :accepted), else: s
      end)

    %{state | sections: sections}
  end

  @doc "Returns true if all sections are accepted."
  def all_accepted?(%{sections: sections}) do
    sections != [] and Enum.all?(sections, &(&1.status == :accepted))
  end

  @doc "Returns true if any section was rejected."
  def any_rejected?(%{sections: sections}) do
    Enum.any?(sections, &(&1.status == :rejected))
  end

  @doc "Export confirmed sections as job specs for the API."
  def to_confirmed_specs(%{sections: sections}) do
    sections
    |> Enum.filter(&(&1.status == :accepted))
    |> Enum.flat_map(& &1.tasks)
  end

  @doc "Reset to hidden state."
  def dismiss(state) do
    %{state | mode: :hidden, sections: [], selected: 0, quest_id: nil, goal: nil}
  end
end
