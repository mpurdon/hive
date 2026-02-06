defmodule Hive.AgentProfile do
  @moduledoc """
  Manages expert agent profiles for bee workers.

  Before a bee starts work, this module checks if the comb has a Claude
  agent file matching the job's technology. If not, it generates one using
  Claude to create an expert profile.

  Agent files are stored per-comb in `<comb_path>/.claude/agents/` and are
  discovered automatically by Claude Code at runtime. Once generated, they
  are cached (the file persists) and reused by all bees on that comb.
  """

  require Logger

  @agents_dir ".claude/agents"

  # Technology keywords mapped to agent names
  @technology_map %{
    "elixir" => "elixir",
    "phoenix" => "elixir",
    "otp" => "elixir",
    "genserver" => "elixir",
    "react" => "react",
    "nextjs" => "react",
    "next.js" => "react",
    "typescript" => "typescript",
    "javascript" => "javascript",
    "node" => "javascript",
    "python" => "python",
    "django" => "python",
    "flask" => "python",
    "fastapi" => "python",
    "rust" => "rust",
    "cargo" => "rust",
    "go" => "go",
    "golang" => "go",
    "ruby" => "ruby",
    "rails" => "ruby",
    "java" => "java",
    "kotlin" => "kotlin",
    "swift" => "swift",
    "terraform" => "terraform",
    "docker" => "docker",
    "kubernetes" => "kubernetes",
    "k8s" => "kubernetes",
    "css" => "css",
    "tailwind" => "css",
    "sql" => "sql",
    "postgres" => "sql",
    "postgresql" => "sql",
    "mysql" => "sql",
    "sqlite" => "sql",
    "graphql" => "graphql",
    "aws" => "aws",
    "lambda" => "aws",
    "vue" => "vue",
    "angular" => "angular",
    "svelte" => "svelte",
    "c++" => "cpp",
    "cpp" => "cpp"
  }

  @doc """
  Ensures an expert agent file exists for the given job in the comb.

  1. Detects the technology from the job title/description
  2. If an agent file already exists, returns its path
  3. If not, generates one via Claude and returns the path
  4. If no technology is detected, returns `{:ok, :no_agent}`

  This function is safe to call from a GenServer `handle_continue` --
  the Claude generation runs synchronously but within the async provision
  pipeline.
  """
  @spec ensure_agent(String.t(), map()) :: {:ok, String.t()} | {:ok, :no_agent} | {:error, term()}
  def ensure_agent(comb_path, job) do
    title = Map.get(job, :title, "") || ""
    description = Map.get(job, :description, "") || ""

    case detect_technology(title, description) do
      nil ->
        {:ok, :no_agent}

      technology ->
        agent_name = "#{technology}-expert"
        agent_path = Path.join([comb_path, @agents_dir, "#{agent_name}.md"])

        if File.exists?(agent_path) do
          Logger.info("Agent profile found: #{agent_name}")
          {:ok, agent_path}
        else
          Logger.info("Generating agent profile: #{agent_name}")
          generate_agent(comb_path, technology)
        end
    end
  end

  @doc """
  Detects the primary technology from job title and description.

  Uses keyword matching against a known technology map. Checks the title
  first (higher signal), then the description. Returns the technology
  name as a string or nil if no match.
  """
  @spec detect_technology(String.t(), String.t()) :: String.t() | nil
  def detect_technology(title, description) do
    text = String.downcase("#{title} #{description}")

    @technology_map
    |> Enum.find_value(fn {keyword, tech} ->
      if String.contains?(text, keyword), do: tech
    end)
  end

  @doc """
  Generates an expert agent file for the given technology.

  Uses Claude headless to generate the content, then writes it to the
  comb's `.claude/agents/` directory.
  """
  @spec generate_agent(String.t(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def generate_agent(comb_path, technology) do
    agent_name = "#{technology}-expert"
    agents_dir = Path.join(comb_path, @agents_dir)
    agent_path = Path.join(agents_dir, "#{agent_name}.md")

    # Ensure .claude/agents/ directory exists
    File.mkdir_p!(agents_dir)

    prompt = build_generation_prompt(technology, agent_name)

    case generate_via_claude(comb_path, prompt) do
      {:ok, content} ->
        File.write!(agent_path, content)
        Logger.info("Agent profile generated: #{agent_path}")
        {:ok, agent_path}

      {:error, reason} ->
        Logger.warning("Failed to generate agent #{agent_name}: #{inspect(reason)}")
        # Write a minimal fallback agent file
        fallback = build_fallback_agent(technology, agent_name)
        File.write!(agent_path, fallback)
        {:ok, agent_path}
    end
  end

  @doc """
  Lists all agent profiles available in a comb's agents directory.
  """
  @spec list_agents(String.t()) :: [String.t()]
  def list_agents(comb_path) do
    agents_dir = Path.join(comb_path, @agents_dir)

    if File.dir?(agents_dir) do
      agents_dir
      |> File.ls!()
      |> Enum.filter(&String.ends_with?(&1, ".md"))
      |> Enum.map(&Path.rootname/1)
    else
      []
    end
  end

  # -- Private: generation -----------------------------------------------------

  defp build_generation_prompt(technology, agent_name) do
    """
    Generate a Claude Code agent file for a #{technology} expert. The file must use this exact format:

    ---
    name: #{agent_name}
    description: Use this agent when working on #{technology} code.
    model: sonnet
    color: blue
    ---

    [Expert instructions in markdown]

    The expert should:
    - Think pragmatically and favor reduced complexity
    - Write clean, idiomatic #{technology} code
    - Follow established conventions and best practices for #{technology}
    - Prefer simple, composable solutions over complex abstractions
    - Include only the YAML frontmatter and markdown instructions, nothing else
    - Be thorough but concise (aim for 50-100 lines of markdown)

    Output ONLY the agent file content with no extra explanation.
    """
  end

  defp generate_via_claude(comb_path, prompt) do
    case Hive.Runtime.Claude.find_executable() do
      {:ok, _} ->
        case Hive.Runtime.Claude.spawn_headless(comb_path, prompt, output_format: :text) do
          {:ok, port} ->
            collect_port_output(port)

          {:error, reason} ->
            {:error, reason}
        end

      {:error, :not_found} ->
        {:error, :claude_not_found}
    end
  end

  defp collect_port_output(port) do
    collect_port_output(port, [])
  end

  defp collect_port_output(port, acc) do
    receive do
      {^port, {:data, data}} ->
        collect_port_output(port, [acc, data])

      {^port, {:exit_status, 0}} ->
        output = IO.iodata_to_binary(acc)
        {:ok, extract_text_content(output)}

      {^port, {:exit_status, code}} ->
        {:error, {:exit_code, code}}
    after
      120_000 ->
        # 2 minute timeout for generation
        Port.close(port)
        {:error, :timeout}
    end
  end

  defp extract_text_content(output) do
    # The output might be stream-json format. Try to extract text content.
    # Each line could be a JSON object with type "assistant" containing text.
    lines = String.split(output, "\n", trim: true)

    text_parts =
      Enum.flat_map(lines, fn line ->
        case Jason.decode(line) do
          {:ok, %{"type" => "assistant", "message" => %{"content" => content}}} ->
            content
            |> Enum.filter(fn block -> Map.get(block, "type") == "text" end)
            |> Enum.map(fn block -> Map.get(block, "text", "") end)

          {:ok, %{"type" => "result", "result" => result}} when is_binary(result) ->
            [result]

          _ ->
            []
        end
      end)

    case text_parts do
      [] ->
        # Fallback: if not JSON, assume raw text
        output

      parts ->
        Enum.join(parts, "")
    end
  end

  defp build_fallback_agent(technology, agent_name) do
    """
    ---
    name: #{agent_name}
    description: Use this agent when working on #{technology} code.
    model: sonnet
    color: blue
    ---

    # #{String.capitalize(technology)} Expert

    You are an expert #{technology} developer. Write clean, idiomatic code following
    established best practices. Favor pragmatic solutions with reduced complexity.

    ## Principles

    - Write simple, readable code
    - Follow #{technology} conventions and idioms
    - Prefer composition over inheritance
    - Keep functions small and focused
    - Handle errors explicitly
    - Write code that is easy to test
    """
  end
end
