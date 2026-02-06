defmodule Hive.TranscriptWatcherTest do
  use ExUnit.Case, async: false

  alias Hive.Repo
  alias Hive.Schema.Bee
  alias Hive.TranscriptWatcher

  @tmp_dir System.tmp_dir!()

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Repo, {:shared, self()})

    {:ok, bee} =
      %Bee{}
      |> Bee.changeset(%{name: "watcher-test-bee"})
      |> Repo.insert()

    # Start watcher with a fast poll interval for testing
    {:ok, pid} = TranscriptWatcher.start_link(poll_interval: 100)
    on_exit(fn -> safe_stop(pid) end)

    %{bee: bee, watcher_pid: pid}
  end

  defp safe_stop(pid) do
    if Process.alive?(pid) do
      GenServer.stop(pid, :normal)
    end
  rescue
    _ -> :ok
  end

  describe "start_link/1" do
    test "starts the watcher process", %{watcher_pid: pid} do
      assert Process.alive?(pid)
    end

    test "registers in the Registry" do
      assert {:ok, _pid} = TranscriptWatcher.lookup()
    end
  end

  describe "watch/2 and unwatch/1" do
    test "adds and removes a bee from the watch list", %{bee: bee} do
      path = create_transcript_file([])

      assert :ok = TranscriptWatcher.watch(bee.id, path)
      assert :ok = TranscriptWatcher.unwatch(bee.id)
    end
  end

  describe "polling" do
    test "detects new transcript entries and records costs", %{bee: bee} do
      path = create_transcript_file([])

      :ok = TranscriptWatcher.watch(bee.id, path)

      # Write a cost entry to the transcript
      entry = %{
        "type" => "result",
        "usage" => %{
          "input_tokens" => 1000,
          "output_tokens" => 500
        },
        "model" => "claude-sonnet-4-20250514"
      }

      append_to_transcript(path, entry)

      # Wait for at least one poll cycle
      Process.sleep(250)

      costs = Hive.Costs.for_bee(bee.id)
      assert length(costs) >= 1
      assert hd(costs).input_tokens == 1000
    end
  end

  describe "final_parse/2" do
    test "performs a one-time full parse of a transcript", %{bee: bee} do
      entries = [
        %{
          "type" => "result",
          "usage" => %{"input_tokens" => 100, "output_tokens" => 50},
          "model" => "claude-sonnet-4-20250514"
        },
        %{
          "type" => "result",
          "usage" => %{"input_tokens" => 200, "output_tokens" => 100},
          "model" => "claude-sonnet-4-20250514"
        }
      ]

      path = create_transcript_file(entries)

      TranscriptWatcher.final_parse(bee.id, path)

      costs = Hive.Costs.for_bee(bee.id)
      assert length(costs) == 2
    end

    test "handles missing file gracefully", %{bee: bee} do
      # Should not crash
      assert :ok = TranscriptWatcher.final_parse(bee.id, "/nonexistent/transcript.jsonl")
    end
  end

  # -- Helpers -----------------------------------------------------------------

  defp create_transcript_file(entries) do
    name = "watcher_test_#{:erlang.unique_integer([:positive])}.jsonl"
    path = Path.join(@tmp_dir, name)

    content =
      entries
      |> Enum.map(&Jason.encode!/1)
      |> Enum.join("\n")

    # Ensure trailing newline if content is non-empty
    content = if content == "", do: "", else: content <> "\n"

    File.write!(path, content)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp append_to_transcript(path, entry) do
    line = Jason.encode!(entry) <> "\n"
    File.write!(path, File.read!(path) <> line)
  end
end
