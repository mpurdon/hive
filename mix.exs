defmodule Hive.MixProject do
  use Mix.Project

  @version "0.2.14"

  def project do
    [
      app: :hive,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Hive.Application, []}
    ]
  end

  defp escript do
    [
      main_module: Hive.CLI,
      name: "hive.escript"
    ]
  end

  defp releases do
    [
      hive: [
        steps: [:assemble],
        applications: [runtime_tools: :permanent]
      ]
    ]
  end

  defp deps do
    [
      {:phoenix_pubsub, "~> 2.1"},
      {:phoenix, "~> 1.7"},
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix_html, "~> 4.1"},
      {:plug_cowboy, "~> 2.7"},
      {:jason, "~> 1.4"},
      {:optimus, "~> 0.5"},
      {:toml, "~> 0.7"},
      {:req, "~> 0.5"},
      {:mox, "~> 1.1", only: :test}
    ]
  end
end
