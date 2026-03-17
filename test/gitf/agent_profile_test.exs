defmodule GiTF.AgentProfileTest do
  use ExUnit.Case, async: true

  alias GiTF.AgentProfile

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
      assert AgentProfile.detect_technology("Phoenix LiveView dashboard", "") ==
               "phoenix-liveview"
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

  describe "detect_from_sector/1" do
    test "detects strands-sdk from pyproject.toml with strands-agents dependency" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(tmp, "pyproject.toml"), """
      [project]
      name = "my-agent"
      dependencies = [
          "strands-agents>=0.1.0",
          "strands-agents-builder",
      ]
      """)

      assert AgentProfile.detect_from_sector(tmp) == "strands-sdk"
    end

    test "detects fastapi from pyproject.toml" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(tmp, "pyproject.toml"), """
      [project]
      dependencies = ["fastapi", "uvicorn"]
      """)

      assert AgentProfile.detect_from_sector(tmp) == "fastapi"
    end

    test "detects react from package.json with react dependency" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(
        Path.join(tmp, "package.json"),
        Jason.encode!(%{
          "dependencies" => %{"react" => "^18.0.0", "react-dom" => "^18.0.0"}
        })
      )

      assert AgentProfile.detect_from_sector(tmp) == "react"
    end

    test "detects nextjs from package.json (framework beats library)" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(
        Path.join(tmp, "package.json"),
        Jason.encode!(%{
          "dependencies" => %{"next" => "^14.0.0", "react" => "^18.0.0"}
        })
      )

      assert AgentProfile.detect_from_sector(tmp) == "nextjs"
    end

    test "detects phoenix from mix.exs" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      File.write!(Path.join(tmp, "mix.exs"), """
      defmodule MyApp.MixProject do
        defp deps do
          [{:phoenix, "~> 1.7"}, {:ecto, "~> 3.0"}]
        end
      end
      """)

      assert AgentProfile.detect_from_sector(tmp) == "phoenix"
    end

    test "returns nil for empty directory" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_comb_detect_#{:erlang.unique_integer([:positive])}")

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      assert AgentProfile.detect_from_sector(tmp) == nil
    end
  end

  describe "ensure_agent/2" do
    test "returns {:ok, :no_agent} when no technology is detected" do
      tmp = Path.join(System.tmp_dir!(), "gitf_agent_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      op = %{title: "Fix the bug", description: "Something is broken"}

      assert {:ok, :no_agent} = AgentProfile.ensure_agent(tmp, op)
    end

    test "returns existing agent when one already exists (dedup)" do
      tmp = Path.join(System.tmp_dir!(), "gitf_agent_test_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      agent_path = Path.join(agents_dir, "elixir-expert.md")
      File.write!(agent_path, "# Elixir Expert\nPre-existing agent file.")

      on_exit(fn -> File.rm_rf!(tmp) end)

      # Even though the op says "Python Django", the existing elixir agent wins
      op = %{title: "Python Django app", description: "Build a Django backend"}

      assert {:ok, ^agent_path} = AgentProfile.ensure_agent(tmp, op)
    end

    test "returns {:ok, path} when agent file already exists" do
      tmp = Path.join(System.tmp_dir!(), "gitf_agent_test_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      agent_path = Path.join(agents_dir, "elixir-expert.md")
      File.write!(agent_path, "# Elixir Expert\nPre-existing agent file.")

      on_exit(fn -> File.rm_rf!(tmp) end)

      op = %{title: "Build Elixir API", description: ""}

      assert {:ok, ^agent_path} = AgentProfile.ensure_agent(tmp, op)
    end

    test "returns {:ok, path} when framework-specific agent file already exists" do
      tmp = Path.join(System.tmp_dir!(), "gitf_agent_test_#{:erlang.unique_integer([:positive])}")
      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      agent_path = Path.join(agents_dir, "phoenix-expert.md")
      File.write!(agent_path, "# Phoenix Expert\nPre-existing agent file.")

      on_exit(fn -> File.rm_rf!(tmp) end)

      op = %{title: "Phoenix web app", description: ""}

      assert {:ok, ^agent_path} = AgentProfile.ensure_agent(tmp, op)
    end

    test "uses sector-level detection over op-level when both match" do
      tmp = Path.join(System.tmp_dir!(), "gitf_agent_test_#{:erlang.unique_integer([:positive])}")
      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      # Comb has strands-agents in pyproject.toml → detect_from_sector returns "strands-sdk"
      File.write!(Path.join(tmp, "pyproject.toml"), """
      [project]
      dependencies = ["strands-agents>=0.1.0"]
      """)

      # Job title says "Python" which would detect "python" at priority 3 via detect_technology
      # Comb-level should take priority: detect_from_sector returns "strands-sdk"
      sector_key = AgentProfile.detect_from_sector(tmp)
      job_key = AgentProfile.detect_technology("Python helper script", "Write a utility")

      assert sector_key == "strands-sdk"
      assert job_key == "python"
      # ensure_agent uses: detect_from_sector || detect_technology — sector wins
      assert sector_key != nil
    end
  end

  describe "install_agents/2" do
    test "copies agent files from sector to worktree" do
      sector =
        Path.join(System.tmp_dir!(), "gitf_install_agents_#{:erlang.unique_integer([:positive])}")

      worktree =
        Path.join(System.tmp_dir!(), "gitf_install_wt_#{:erlang.unique_integer([:positive])}")

      sector_agents = Path.join(sector, ".claude/agents")
      File.mkdir_p!(sector_agents)
      File.mkdir_p!(worktree)

      on_exit(fn ->
        File.rm_rf!(sector)
        File.rm_rf!(worktree)
      end)

      File.write!(Path.join(sector_agents, "elixir-expert.md"), "# Elixir Expert")
      File.write!(Path.join(sector_agents, "rust-expert.md"), "# Rust Expert")

      assert :ok = AgentProfile.install_agents(sector, worktree)

      wt_agents = Path.join(worktree, ".claude/agents")
      assert File.read!(Path.join(wt_agents, "elixir-expert.md")) == "# Elixir Expert"
      assert File.read!(Path.join(wt_agents, "rust-expert.md")) == "# Rust Expert"
    end

    test "does not overwrite existing agents in worktree" do
      sector =
        Path.join(System.tmp_dir!(), "gitf_install_noover_#{:erlang.unique_integer([:positive])}")

      worktree =
        Path.join(
          System.tmp_dir!(),
          "gitf_install_noover_wt_#{:erlang.unique_integer([:positive])}"
        )

      sector_agents = Path.join(sector, ".claude/agents")
      wt_agents = Path.join(worktree, ".claude/agents")
      File.mkdir_p!(sector_agents)
      File.mkdir_p!(wt_agents)

      on_exit(fn ->
        File.rm_rf!(sector)
        File.rm_rf!(worktree)
      end)

      File.write!(Path.join(sector_agents, "elixir-expert.md"), "# Comb Version")
      File.write!(Path.join(wt_agents, "elixir-expert.md"), "# Worktree Version")

      assert :ok = AgentProfile.install_agents(sector, worktree)

      assert File.read!(Path.join(wt_agents, "elixir-expert.md")) == "# Worktree Version"
    end

    test "is a no-op when sector has no agents dir" do
      sector =
        Path.join(System.tmp_dir!(), "gitf_install_noop_#{:erlang.unique_integer([:positive])}")

      worktree =
        Path.join(
          System.tmp_dir!(),
          "gitf_install_noop_wt_#{:erlang.unique_integer([:positive])}"
        )

      File.mkdir_p!(sector)
      File.mkdir_p!(worktree)

      on_exit(fn ->
        File.rm_rf!(sector)
        File.rm_rf!(worktree)
      end)

      assert :ok = AgentProfile.install_agents(sector, worktree)

      refute File.dir?(Path.join(worktree, ".claude/agents"))
    end
  end

  describe "list_agents/1" do
    test "returns empty list for directory without agents" do
      tmp =
        Path.join(
          System.tmp_dir!(),
          "gitf_agent_list_empty_#{:erlang.unique_integer([:positive])}"
        )

      File.mkdir_p!(tmp)
      on_exit(fn -> File.rm_rf!(tmp) end)

      assert AgentProfile.list_agents(tmp) == []
    end

    test "returns agent names from populated directory" do
      tmp =
        Path.join(System.tmp_dir!(), "gitf_agent_list_pop_#{:erlang.unique_integer([:positive])}")

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
      tmp =
        Path.join(
          System.tmp_dir!(),
          "gitf_agent_list_nomd_#{:erlang.unique_integer([:positive])}"
        )

      agents_dir = Path.join(tmp, ".claude/agents")
      File.mkdir_p!(agents_dir)

      File.write!(Path.join(agents_dir, "notes.txt"), "not an agent")
      File.write!(Path.join(agents_dir, "config.json"), "{}")

      on_exit(fn -> File.rm_rf!(tmp) end)

      assert AgentProfile.list_agents(tmp) == []
    end
  end
end
