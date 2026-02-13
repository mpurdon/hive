defmodule Mix.Tasks.Hive.Test.E2e do
  @moduledoc """
  Runs Hive E2E integration tests.

      mix hive.test.e2e                          # run all E2E tests
      mix hive.test.e2e test/e2e/quest*.exs      # run specific files
      mix hive.test.e2e --json                   # write JSON report
      mix hive.test.e2e --timeout 30000          # global scenario timeout
      mix hive.test.e2e --remote node@host       # connect to running instance

  E2E tests live in `test/e2e/` and use `Hive.TestDriver.Scenario` for
  isolated environments, mock Claude executables, and auto-waiting assertions.

  ## Options

    * `--json` — write JSON report to `_build/test/e2e_report.json`
    * `--timeout` — global scenario timeout in ms (passed as ExUnit config)
    * `--remote` — connect to a running Hive instance before running tests
    * `--trace` — show detailed test output (passed through to ExUnit)
    * `--seed` — randomization seed (passed through to ExUnit)
  """

  use Mix.Task

  @shortdoc "Run Hive E2E integration tests"

  @default_path "test/e2e"

  @impl true
  def run(args) do
    {opts, files, _} =
      OptionParser.parse(args,
        strict: [
          json: :boolean,
          timeout: :integer,
          remote: :string,
          trace: :boolean,
          seed: :integer
        ]
      )

    if remote = opts[:remote] do
      connect_remote(remote)
    end

    # Build the mix test args
    test_args = build_test_args(files, opts)

    # Set environment variable for JSON reporting if requested
    if opts[:json] do
      System.put_env("HIVE_E2E_JSON_REPORT", "true")
    end

    if timeout = opts[:timeout] do
      System.put_env("HIVE_E2E_TIMEOUT", to_string(timeout))
    end

    Mix.Task.run("test", test_args)
  end

  defp build_test_args([], opts) do
    args = [@default_path, "--include", "e2e"]
    args ++ passthrough_args(opts)
  end

  defp build_test_args(files, opts) do
    args = files ++ ["--include", "e2e"]
    args ++ passthrough_args(opts)
  end

  defp passthrough_args(opts) do
    args = []
    args = if opts[:trace], do: args ++ ["--trace"], else: args
    args = if opts[:seed], do: args ++ ["--seed", to_string(opts[:seed])], else: args
    args
  end

  defp connect_remote(node_string) do
    node = String.to_atom(node_string)
    local_name = :"hive_e2e_#{:erlang.unique_integer([:positive])}@127.0.0.1"

    case Node.start(local_name) do
      {:ok, _} ->
        Node.set_cookie(:hive_test)

        if Node.connect(node) do
          Mix.shell().info("Connected to #{node}")
        else
          Mix.shell().error("Failed to connect to #{node}")
          System.halt(1)
        end

      {:error, reason} ->
        Mix.shell().error("Failed to start local node: #{inspect(reason)}")
        System.halt(1)
    end
  end
end
