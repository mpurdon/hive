defmodule GiTF.Dashboard.PlanLive do
  @moduledoc "Interactive planning UI for mission plan generation, comparison, and confirmation."

  use Phoenix.LiveView

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case GiTF.Missions.get(id) do
      {:ok, mission} ->
        # Check if plans already exist
        existing_plans = GiTF.Missions.get_artifact(id, "planning")
        step = if existing_plans, do: :compare, else: :generate

        {:ok,
         socket
         |> assign(:page_title, "Plan: #{Map.get(mission, :name, "Mission")}")
         |> assign(:current_path, "/dashboard/missions")
         |> assign(:mission, mission)
         |> assign(:step, step)
         |> assign(:plans, if(existing_plans, do: normalize_plans(existing_plans), else: []))
         |> assign(:selected_plan, nil)
         |> assign(:loading, false)
         |> assign(:feedback, "")
         |> assign(:created_ops, [])}

      {:error, _} ->
        {:ok,
         socket
         |> put_flash(:error, "Mission not found.")
         |> push_navigate(to: "/dashboard/missions")}
    end
  end

  @impl true
  def handle_event("generate", _params, socket) do
    mission = socket.assigns.mission

    Task.async(fn ->
      {:plans, GiTF.Major.Planner.generate_candidate_plans(mission.id, %{goal: mission.goal})}
    end)

    {:noreply, assign(socket, :loading, true)}
  end

  def handle_event("select_plan", %{"index" => idx_str}, socket) do
    idx = String.to_integer(idx_str)
    plan = Enum.at(socket.assigns.plans, idx)
    {:noreply, assign(socket, selected_plan: plan, step: :review)}
  end

  def handle_event("back_to_compare", _params, socket) do
    {:noreply, assign(socket, step: :compare, selected_plan: nil)}
  end

  def handle_event("update_feedback", %{"feedback" => text}, socket) do
    {:noreply, assign(socket, :feedback, text)}
  end

  def handle_event("revise", _params, socket) do
    mission = socket.assigns.mission

    Task.async(fn ->
      {:plans,
       GiTF.Major.Planner.generate_candidate_plans(mission.id, %{
         goal: mission.goal,
         feedback: socket.assigns.feedback
       })}
    end)

    {:noreply, assign(socket, loading: true, step: :generate, feedback: "")}
  end

  def handle_event("confirm", _params, socket) do
    mission = socket.assigns.mission
    plan = socket.assigns.selected_plan

    case GiTF.Major.Planner.create_jobs_from_plan(mission.id, plan) do
      {:ok, ops} ->
        {:noreply,
         socket
         |> assign(:step, :confirmed)
         |> assign(:created_ops, ops)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to confirm plan: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_info({ref, {:plans, result}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    case result do
      {:ok, plan_data} ->
        plans = normalize_plans(plan_data)

        {:noreply,
         socket
         |> assign(:loading, false)
         |> assign(:plans, plans)
         |> assign(:step, :compare)}

      {:error, reason} ->
        {:noreply,
         socket
         |> assign(:loading, false)
         |> put_flash(:error, "Plan generation failed: #{inspect(reason)}")}
    end
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp normalize_plans(%{candidates: candidates}) when is_list(candidates), do: candidates
  defp normalize_plans(%{plans: plans}) when is_list(plans), do: plans
  defp normalize_plans(plans) when is_list(plans), do: plans
  defp normalize_plans(plan) when is_map(plan), do: [plan]
  defp normalize_plans(_), do: []

  @impl true
  def render(assigns) do
    ~H"""
    <.live_component module={GiTF.Dashboard.AppLayout} id="layout" current_path={@current_path} flash={@flash}>
      <div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:1.25rem">
        <div>
          <h1 class="page-title" style="margin-bottom:0.25rem">Plan: {Map.get(@mission, :name, "Mission")}</h1>
          <div style="color:#8b949e; font-size:0.85rem">{Map.get(@mission, :goal, "")}</div>
        </div>
        <a href={"/dashboard/missions/#{@mission.id}"} class="btn btn-grey">Back to Mission</a>
      </div>

      <%!-- Step indicator --%>
      <div class="tab-bar" style="margin-bottom:1.5rem">
        <div class={"tab #{if @step == :generate, do: "tab-active"}"}>1. Generate</div>
        <div class={"tab #{if @step == :compare, do: "tab-active"}"}>2. Compare</div>
        <div class={"tab #{if @step == :review, do: "tab-active"}"}>3. Review</div>
        <div class={"tab #{if @step == :confirmed, do: "tab-active"}"}>4. Confirmed</div>
      </div>

      <%= case @step do %>
        <% :generate -> %>
          <div class="panel" style="text-align:center; padding:3rem">
            <%= if @loading do %>
              <div class="loading-spinner" style="margin:0 auto 1rem"></div>
              <p style="color:#8b949e">Generating plan candidates...</p>
            <% else %>
              <p style="color:#8b949e; margin-bottom:1.25rem">
                The planner will analyze the mission goal and generate multiple candidate strategies.
              </p>
              <button phx-click="generate" class="btn btn-green">Generate Plans</button>
            <% end %>
          </div>

        <% :compare -> %>
          <div class="grid-2">
            <%= for {plan, idx} <- Enum.with_index(@plans) do %>
              <div
                class="plan-card"
                phx-click="select_plan"
                phx-value-index={idx}
              >
                <div class="plan-card-title">
                  {Map.get(plan, :strategy, Map.get(plan, :name, "Plan #{idx + 1}"))}
                </div>
                <%= if Map.get(plan, :score) do %>
                  <div style="margin-bottom:0.5rem">
                    <div style="display:flex; justify-content:space-between; font-size:0.8rem; color:#8b949e; margin-bottom:0.25rem">
                      <span>Score</span>
                      <span>{Float.round(plan.score * 100, 0)}%</span>
                    </div>
                    <div class="score-bar">
                      <div class="score-bar-fill" style={"width:#{plan.score * 100}%"}></div>
                    </div>
                  </div>
                <% end %>
                <div style="font-size:0.85rem; color:#8b949e">
                  {task_count(plan)} tasks
                </div>
                <%= if Map.get(plan, :description) do %>
                  <div style="font-size:0.85rem; color:#8b949e; margin-top:0.5rem">
                    {String.slice(plan.description, 0, 150)}{if String.length(plan.description || "") > 150, do: "..."}
                  </div>
                <% end %>
              </div>
            <% end %>
          </div>
          <%= if @plans == [] do %>
            <div class="empty">No plan candidates available. Try generating again.</div>
          <% end %>

        <% :review -> %>
          <div class="panel">
            <div class="panel-title">
              {Map.get(@selected_plan, :strategy, Map.get(@selected_plan, :name, "Selected Plan"))}
            </div>
            <%= if Map.get(@selected_plan, :description) do %>
              <p style="color:#8b949e; margin-bottom:1rem">{@selected_plan.description}</p>
            <% end %>

            <div class="panel-title" style="margin-top:1rem">Tasks</div>
            <%= for {task, idx} <- Enum.with_index(get_tasks(@selected_plan)) do %>
              <div style="padding:0.75rem 0; border-bottom:1px solid #21262d">
                <div style="font-weight:500; color:#f0f6fc">
                  {idx + 1}. {Map.get(task, :title, Map.get(task, :name, "Task #{idx + 1}"))}
                </div>
                <%= if Map.get(task, :description) do %>
                  <div style="font-size:0.85rem; color:#8b949e; margin-top:0.25rem">{task.description}</div>
                <% end %>
                <%= if Map.get(task, :target_files) do %>
                  <div style="font-size:0.8rem; color:#8b949e; margin-top:0.25rem; font-family:monospace">
                    {Enum.join(List.wrap(task.target_files), ", ")}
                  </div>
                <% end %>
                <%= if Map.get(task, :acceptance_criteria) do %>
                  <div style="font-size:0.8rem; color:#3fb950; margin-top:0.25rem">
                    ✓ {task.acceptance_criteria}
                  </div>
                <% end %>
              </div>
            <% end %>

            <div style="margin-top:1.25rem">
              <div class="form-group">
                <label class="form-label">Revision feedback (optional)</label>
                <textarea
                  class="form-textarea"
                  phx-change="update_feedback"
                  name="feedback"
                  placeholder="Describe changes you'd like..."
                  style="min-height:80px"
                >{@feedback}</textarea>
              </div>
            </div>

            <div class="action-bar">
              <button phx-click="back_to_compare" class="btn btn-grey">Back</button>
              <%= if String.trim(@feedback) != "" do %>
                <button phx-click="revise" class="btn btn-blue">Revise</button>
              <% end %>
              <button phx-click="confirm" class="btn btn-green">Confirm Plan</button>
            </div>
          </div>

        <% :confirmed -> %>
          <div class="panel" style="text-align:center; padding:2rem">
            <div style="font-size:1.5rem; color:#3fb950; margin-bottom:0.75rem">✓</div>
            <h2 style="color:#f0f6fc; margin-bottom:0.5rem">Plan Confirmed</h2>
            <p style="color:#8b949e; margin-bottom:1.25rem">
              {length(@created_ops)} ops have been created.
            </p>
            <a href={"/dashboard/missions/#{@mission.id}"} class="btn btn-blue">View Mission</a>
          </div>
      <% end %>
    </.live_component>
    """
  end

  defp task_count(plan) do
    tasks = Map.get(plan, :tasks, Map.get(plan, :ops, Map.get(plan, :specs, [])))
    length(List.wrap(tasks))
  end

  defp get_tasks(plan) do
    Map.get(plan, :tasks, Map.get(plan, :ops, Map.get(plan, :specs, [])))
    |> List.wrap()
  end
end
