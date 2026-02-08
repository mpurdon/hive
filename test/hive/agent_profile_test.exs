defmodule Hive.AgentProfileTest do
  use ExUnit.Case, async: true

  alias Hive.AgentProfile

  describe "detect_technology/2" do
    test "identifies Elixir from title keywords" do
      assert AgentProfile.detect_technology("Build an Elixir API", "") == "elixir"
    end

    test "identifies Phoenix from keyword (framework-specific)" do
      assert AgentProfile.detect_technology("Phoenix web app", "") == "phoenix"
    end

    test "identifies Elixir/OTP from OTP + supervisor combo" do
      assert AgentProfile.detect_technology("OTP supervisor tree", "") == "elixir-otp"
    end

    test "identifies bare OTP as elixir fallback" do
      assert AgentProfile.detect_technology("OTP application", "") == "elixir"
    end

    test "identifies Django from description (framework-specific)" do
      assert AgentProfile.detect_technology("Build API", "Use Django for the backend") == "django"
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

    test "identifies Rails from keyword (framework-specific)" do
      assert AgentProfile.detect_technology("Rails application", "") == "rails"
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

    # Tiered priority tests

    test "Strands SDK multi-keyword combo wins over base python" do
      assert AgentProfile.detect_technology("Build a Strands SDK agent", "") == "strands-sdk"
    end

    test "single Strands keyword detects strands-sdk at priority 2" do
      assert AgentProfile.detect_technology("Use Strands for the project", "") == "strands-sdk"
    end

    test "CDK infrastructure combo wins over bare aws" do
      assert AgentProfile.detect_technology("CDK infrastructure deployment", "") == "aws-cdk"
    end

    test "bare CDK detects aws-cdk at priority 2" do
      assert AgentProfile.detect_technology("Deploy with CDK", "") == "aws-cdk"
    end

    test "Next.js keyword detects nextjs" do
      assert AgentProfile.detect_technology("Build a Next.js app", "") == "nextjs"
    end

    test "nextjs keyword detects nextjs" do
      assert AgentProfile.detect_technology("Use nextjs for frontend", "") == "nextjs"
    end

    test "FastAPI detects fastapi" do
      assert AgentProfile.detect_technology("FastAPI backend service", "") == "fastapi"
    end

    test "Flask detects flask" do
      assert AgentProfile.detect_technology("Flask web application", "") == "flask"
    end

    test "Python falls back to base python when no framework keyword" do
      assert AgentProfile.detect_technology("Python script", "") == "python"
    end

    test "Phoenix LiveView combo wins over bare phoenix" do
      assert AgentProfile.detect_technology("Phoenix LiveView dashboard", "") == "phoenix-liveview"
    end

    test "GenServer keyword detects elixir-otp" do
      assert AgentProfile.detect_technology("Build a GenServer", "") == "elixir-otp"
    end

    test "Terraform module combo detects terraform-iac" do
      assert AgentProfile.detect_technology("Terraform module for VPC", "") == "terraform-iac"
    end

    test "bare Terraform detects terraform at priority 2" do
      assert AgentProfile.detect_technology("Terraform config", "") == "terraform"
    end

    test "React Native combo detects react-native" do
      assert AgentProfile.detect_technology("React Native mobile app", "") == "react-native"
    end

    test "priority 1 beats priority 2 when both match" do
      # "OTP supervisor" matches priority 1 {otp, supervisor} -> elixir-otp
      # and priority 3 {otp} -> elixir. Priority 1 wins.
      assert AgentProfile.detect_technology("Build OTP supervisor", "") == "elixir-otp"
    end

    test "framework beats language when both present" do
      # Django (priority 2) beats Python (priority 3)
      assert AgentProfile.detect_technology("Python Django app", "") == "django"
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

    test "returns {:ok, path} when framework-specific agent file already exists" do
      tmp = Path.join(System.tmp_dir!(), "hive_agent_test_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      agent_path = Path.join(agents_dir, "phoenix-expert.md")
      File.write!(agent_path, "# Phoenix Expert\nPre-existing agent file.")

      on_exit(fn -> File.rm_rf!(tmp) end)

      job = %{title: "Phoenix web app", description: ""}

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
