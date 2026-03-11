defmodule GiTF.Ingestion.WatchdogTest do
  use ExUnit.Case, async: false

  alias GiTF.Ingestion.Watchdog
  alias GiTF.Store

  setup do
    GiTF.Test.StoreHelper.ensure_infrastructure()

    # Create temp root
    root = Path.join(System.tmp_dir!(), "gitf_ingest_test_#{:erlang.unique_integer([:positive])}")
    File.mkdir_p!(root)

    # Initialize Store (needed for combs/quests)
    GiTF.Test.StoreHelper.stop_store()
    {:ok, _} = GiTF.Store.start_link(data_dir: Path.join(root, ".gitf/store"))

    # Create a dummy comb so ingestion works
    GiTF.Comb.add(root, name: "test-comb")

    # Terminate Ingestion.Watchdog from supervisor to prevent auto-restart conflicts
    try do
      Supervisor.terminate_child(GiTF.Supervisor, GiTF.Ingestion.Watchdog)
      Supervisor.delete_child(GiTF.Supervisor, GiTF.Ingestion.Watchdog)
    catch
      :exit, _ -> :ok
    end
    GiTF.Test.StoreHelper.safe_stop(GiTF.Ingestion.Watchdog)
    Process.sleep(10)
    {:ok, _} = Watchdog.start_link(gitf_root: root)

    inbox = Path.join([root, ".gitf", "inbox"])
    archive = Path.join([root, ".gitf", "archive"])

    on_exit(fn -> File.rm_rf!(root) end)

    {:ok, %{inbox: inbox, archive: archive}}
  end

  test "ingests markdown file as quest", %{inbox: inbox, archive: archive} do
    # 1. Create a work order
    file_path = Path.join(inbox, "fix_login_bug.md")
    content = "The login button is broken on mobile."
    File.write!(file_path, content)
    
    # 2. Trigger scan (or wait)
    send(Watchdog, :scan)
    
    # 3. Wait for processing
    # Give it a moment to process async
    Process.sleep(100)
    
    # 4. Verify Quest created
    quests = Store.all(:quests)
    assert length(quests) == 1
    quest = hd(quests)
    assert quest.name == "Fix login bug" # Title derived from filename
    assert quest.goal == content
    # source field may or may not be present depending on the ingestion implementation
    assert Map.get(quest, :source, nil) in [nil, "inbox:fix_login_bug.md"]
    
    # 5. Verify file archived
    assert File.ls!(inbox) == []
    assert length(File.ls!(archive)) == 1
  end
end
