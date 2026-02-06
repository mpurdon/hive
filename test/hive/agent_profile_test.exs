defmodule Hive.AgentProfileTest do
  use ExUnit.Case, async: true

  alias Hive.AgentProfile

  describe "detect_technology/2" do
    test "identifies Elixir from title keywords" do
      assert AgentProfile.detect_technology("Build an Elixir API", "") == "elixir"
    end

    test "identifies Elixir from Phoenix keyword" do
      assert AgentProfile.detect_technology("Phoenix web app", "") == "elixir"
    end

    test "identifies Elixir from OTP keyword" do
      assert AgentProfile.detect_technology("OTP supervisor tree", "") == "elixir"
    end

    test "identifies Python from description" do
      assert AgentProfile.detect_technology("Build API", "Use Django for the backend") == "python"
    end

    test "identifies Rust from title" do
      assert AgentProfile.detect_technology("Rust CLI tool", "") == "rust"
    end

    test "identifies Go from golang keyword" do
      assert AgentProfile.detect_technology("Golang microservice", "") == "go"
    end

    test "identifies Kubernetes from k8s keyword" do
      assert AgentProfile.detect_technology("Deploy with k8s", "") == "kubernetes"
    end

    test "identifies Ruby from Rails keyword" do
      assert AgentProfile.detect_technology("Rails application", "") == "ruby"
    end

    test "returns nil for unrecognized text" do
      assert AgentProfile.detect_technology("Fix the bug", "Something is broken") == nil
    end

    test "returns nil for empty strings" do
      assert AgentProfile.detect_technology("", "") == nil
    end

    test "is case-insensitive" do
      assert AgentProfile.detect_technology("ELIXIR project", "") == "elixir"
      assert AgentProfile.detect_technology("React Component", "") == "react"
    end
  end

  describe "ensure_agent/2" do
    test "returns {:ok, :no_agent} when no technology is detected" do
      job = %{title: "Fix the bug", description: "Something is broken"}

      assert {:ok, :no_agent} = AgentProfile.ensure_agent(System.tmp_dir!(), job)
    end

    test "returns {:ok, path} when agent file already exists" do
      tmp = Path.join(System.tmp_dir!(), "hive_agent_test_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      agent_path = Path.join(agents_dir, "elixir-expert.md")
      File.write!(agent_path, "# Elixir Expert\nPre-existing agent file.")

      on_exit(fn -> File.rm_rf!(tmp) end)

      job = %{title: "Build Elixir API", description: ""}

      assert {:ok, ^agent_path} = AgentProfile.ensure_agent(tmp, job)
    end
  end

  describe "list_agents/1" do
    test "returns empty list for directory without agents" do
      tmp = Path.join(System.tmp_dir!(), "hive_agent_list_empty_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      assert AgentProfile.list_agents(tmp) == []
    end

    test "returns agent names from populated directory" do
      tmp = Path.join(System.tmp_dir!(), "hive_agent_list_pop_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      File.write!(Path.join(agents_dir, "elixir-expert.md"), "# Elixir")
      File.write!(Path.join(agents_dir, "rust-expert.md"), "# Rust")
      File.write!(Path.join(agents_dir, "not-an-agent.txt"), "ignored")

      on_exit(fn -> File.rm_rf!(tmp) end)

      agents = AgentProfile.list_agents(tmp) |> Enum.sort()
      assert agents == ["elixir-expert", "rust-expert"]
    end

    test "ignores non-markdown files" do
      tmp = Path.join(System.tmp_dir!(), "hive_agent_list_nomd_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      File.write!(Path.join(agents_dir, "notes.txt"), "not an agent")
      File.write!(Path.join(agents_dir, "config.json"), "{}")

      on_exit(fn -> File.rm_rf!(tmp) end)

      assert AgentProfile.list_agents(tmp) == []
    end
  end
end
