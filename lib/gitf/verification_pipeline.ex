defmodule GiTF.VerificationPipeline do
  @moduledoc """
  Concurrent verification pipeline using Task.Supervisor.

  Processes ops needing verification in parallel (up to max_concurrency),
  with backpressure to prevent overwhelming the system.

  Replaces sequential one-at-a-time verification with controlled
  parallel execution.
  """

  require Logger

  @max_concurrency 3
  @task_timeout :timer.minutes(3)

  @doc """
  Runs a single verification cycle: finds all pending ops and verifies
  them concurrently. Emits telemetry and returns {verified, failed}.

  Designed to be called from Major's periodic check or Tachikoma.
  """
  @spec run_cycle() :: {non_neg_integer(), non_neg_integer()}
  def run_cycle do
    start_time = System.monotonic_time()
    ops = GiTF.Audit.jobs_needing_verification()

    if ops == [] do
      {0, 0}
    else
      Logger.info("VerificationPipeline: starting cycle with #{length(ops)} pending ops")
      {verified, failed} = verify_batch(ops)

      duration = System.monotonic_time() - start_time

      :telemetry.execute(
        [:gitf, :verification_pipeline, :cycle],
        %{
          duration: duration,
          verified: verified,
          failed: failed,
          total: length(ops)
        },
        %{}
      )

      Logger.info(
        "VerificationPipeline: cycle complete — #{verified} passed, #{failed} failed"
      )

      {verified, failed}
    end
  end

  @doc """
  Verifies all pending ops concurrently (up to @max_concurrency at a time).
  Returns {verified_count, failed_count}.
  """
  @spec verify_pending() :: {non_neg_integer(), non_neg_integer()}
  def verify_pending do
    ops = GiTF.Audit.jobs_needing_verification()
    verify_batch(ops)
  end

  @doc """
  Verifies a batch of ops concurrently.
  """
  @spec verify_batch([map()]) :: {non_neg_integer(), non_neg_integer()}
  def verify_batch([]), do: {0, 0}

  def verify_batch(ops) do
    ops
    |> Task.Supervisor.async_stream_nolink(
      GiTF.TaskSupervisor,
      &verify_one/1,
      max_concurrency: @max_concurrency,
      timeout: @task_timeout,
      on_timeout: :kill_task
    )
    |> Enum.reduce({0, 0}, fn
      {:ok, {:ok, :pass, _}}, {v, f} ->
        {v + 1, f}

      {:ok, {:ok, :fail, _}}, {v, f} ->
        {v, f + 1}

      {:exit, reason}, {v, f} ->
        Logger.warning("VerificationPipeline: task exited — #{inspect(reason)}")
        {v, f + 1}

      other, {v, f} ->
        Logger.warning("VerificationPipeline: unexpected result — #{inspect(other)}")
        {v, f + 1}
    end)
  end

  defp verify_one(op) do
    op_id = op.id

    :telemetry.execute(
      [:gitf, :verification_pipeline, :op_start],
      %{system_time: System.system_time()},
      %{op_id: op_id}
    )

    start = System.monotonic_time()
    result = GiTF.Audit.verify_job(op_id)

    status =
      case result do
        {:ok, :pass, _} -> :pass
        {:ok, :fail, _} -> :fail
        _ -> :error
      end

    :telemetry.execute(
      [:gitf, :verification_pipeline, :op_complete],
      %{duration: System.monotonic_time() - start},
      %{op_id: op_id, status: status}
    )

    Logger.info("VerificationPipeline: op #{op_id} — #{status}")
    result
  rescue
    e ->
      Logger.warning(
        "VerificationPipeline: verification crashed for #{op.id} — #{Exception.message(e)}"
      )

      :telemetry.execute(
        [:gitf, :verification_pipeline, :op_complete],
        %{duration: 0},
        %{op_id: op.id, status: :crash}
      )

      {:error, :verification_crashed}
  end
end
