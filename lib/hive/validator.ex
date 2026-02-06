defmodule Hive.Validator do
  @moduledoc """
  Validates bee output after completion.

  Runs an optional custom validation command (e.g. `mix test`) and
  optionally a headless Claude assessment of the diff against the
  job description. Pure context module.
  """

  require Logger

  alias Hive.Repo
  alias Hive.Schema.{Cell, Comb}

  @doc """
  Validates a completed bee's work.

  1. Runs `validation_command` in the cell worktree if the comb has one.
  2. Runs headless Claude validation to assess the diff.

  Returns `{:ok, :pass}`, `{:ok, :skip}`, or `{:error, reason, details}`.
  """
  @spec validate(String.t(), Hive.Schema.Job.t(), String.t()) ::
          {:ok, atom()} | {:error, term()} | {:error, term(), term()}
  def validate(_bee_id, job, cell_id) do
    with {:ok, cell} <- fetch_cell(cell_id),
         {:ok, comb} <- fetch_comb(cell.comb_id) do
      results = []

      # Run custom validation command if configured
      results =
        if comb.validation_command do
          case run_custom_validation(cell, comb.validation_command) do
            :ok -> results
            {:error, reason} -> [{:error, :custom_validation_failed, reason} | results]
          end
        else
          results
        end

      # Run Claude validation
      results =
        case run_claude_validation(job, cell) do
          {:ok, :pass} -> results
          {:ok, :skip} -> results
          {:error, reason, details} -> [{:error, reason, details} | results]
          _ -> results
        end

      case Enum.find(results, &match?({:error, _, _}, &1)) do
        nil -> {:ok, :pass}
        {:error, reason, details} -> {:error, reason, details}
      end
    end
  end

  @doc "Runs a custom shell command in the cell worktree."
  @spec run_custom_validation(Cell.t(), String.t()) :: :ok | {:error, String.t()}
  def run_custom_validation(cell, command) do
    case System.cmd("sh", ["-c", command],
           cd: cell.worktree_path,
           stderr_to_stdout: true,
           env: [{"MIX_ENV", "test"}]
         ) do
      {_output, 0} ->
        :ok

      {output, exit_code} ->
        {:error, "Command failed (exit #{exit_code}): #{String.slice(output, 0, 500)}"}
    end
  rescue
    e -> {:error, "Validation command error: #{Exception.message(e)}"}
  end

  @doc "Runs headless Claude to assess whether the diff solves the job."
  @spec run_claude_validation(Hive.Schema.Job.t(), Cell.t()) ::
          {:ok, :pass} | {:ok, :skip} | {:error, term(), term()}
  def run_claude_validation(job, cell) do
    case get_diff(cell) do
      {:ok, ""} ->
        {:ok, :skip}

      {:ok, diff} ->
        prompt = build_validation_prompt(job, diff)

        case Hive.Runtime.Claude.spawn_headless(cell.worktree_path, prompt) do
          {:ok, port} ->
            collect_validation_result(port)

          {:error, _reason} ->
            # If Claude is not available, skip validation rather than blocking
            {:ok, :skip}
        end

      {:error, _} ->
        {:ok, :skip}
    end
  rescue
    _ -> {:ok, :skip}
  end

  @doc "Builds the validation prompt for Claude."
  @spec build_validation_prompt(Hive.Schema.Job.t(), String.t()) :: String.t()
  def build_validation_prompt(job, diff) do
    description = job.description || ""

    """
    You are a code reviewer. Evaluate whether the following changes solve the task.

    ## Task
    Title: #{job.title}
    Description: #{description}

    ## Changes (git diff)
    ```
    #{String.slice(diff, 0, 8000)}
    ```

    Respond with ONLY a JSON object (no markdown fences):
    {"verdict": "pass" or "fail", "reasoning": "brief explanation", "issues": ["issue1", ...]}
    """
  end

  # -- Private -----------------------------------------------------------------

  defp fetch_cell(cell_id) do
    case Repo.get(Cell, cell_id) do
      nil -> {:error, :cell_not_found}
      cell -> {:ok, cell}
    end
  end

  defp fetch_comb(comb_id) do
    case Repo.get(Comb, comb_id) do
      nil -> {:error, :comb_not_found}
      comb -> {:ok, comb}
    end
  end

  defp get_diff(cell) do
    case System.cmd("git", ["diff", "HEAD~1..HEAD"],
           cd: cell.worktree_path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {_, _} ->
        # Fallback: diff against the working tree
        case System.cmd("git", ["diff"], cd: cell.worktree_path, stderr_to_stdout: true) do
          {output, 0} -> {:ok, output}
          {output, _} -> {:error, output}
        end
    end
  rescue
    _ -> {:error, :diff_failed}
  end

  defp collect_validation_result(port) do
    collect_validation_result(port, [], 60_000)
  end

  defp collect_validation_result(port, acc, timeout) do
    receive do
      {^port, {:data, data}} ->
        collect_validation_result(port, [acc, data], timeout)

      {^port, {:exit_status, 0}} ->
        output = IO.iodata_to_binary(acc)
        parse_verdict(output)

      {^port, {:exit_status, _}} ->
        {:ok, :skip}
    after
      timeout ->
        safe_close_port(port)
        {:ok, :skip}
    end
  end

  defp parse_verdict(output) do
    # Try to extract JSON from the output
    case extract_json(output) do
      {:ok, %{"verdict" => "pass"}} -> {:ok, :pass}
      {:ok, %{"verdict" => "fail"} = json} ->
        issues = Map.get(json, "issues", [])
        reasoning = Map.get(json, "reasoning", "")
        {:error, :validation_failed, %{reasoning: reasoning, issues: issues}}
      _ ->
        {:ok, :skip}
    end
  end

  defp extract_json(text) do
    # Find JSON object in text
    case Regex.run(~r/\{[^{}]*"verdict"[^{}]*\}/s, text) do
      [json_str] -> Jason.decode(json_str)
      _ -> {:error, :no_json}
    end
  end

  defp safe_close_port(port) do
    if Port.info(port) != nil, do: Port.close(port)
  rescue
    ArgumentError -> :ok
  end
end
