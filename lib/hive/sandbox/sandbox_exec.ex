defmodule Hive.Sandbox.SandboxExec do
  @moduledoc """
  macOS sandbox-exec adapter.

  Wraps commands using the built-in macOS `sandbox-exec` tool with
  dynamically generated SBPL (Seatbelt Profile Language) profiles.
  Provides kernel-level sandboxing on macOS similar to Bubblewrap on Linux.
  """
  @behaviour Hive.Sandbox

  def wrap_command(cmd, args, opts) do
    cwd = Keyword.get(opts, :cd, File.cwd!())
    risk_level = Keyword.get(opts, :risk_level, :low)

    profile = build_profile(cwd, risk_level)

    {"sandbox-exec", ["-p", profile, cmd | args], opts}
  end

  def available? do
    match?({:unix, :darwin}, :os.type())
  end

  def name, do: "sandbox-exec"

  defp build_profile(cwd, risk_level) do
    escaped_cwd = escape_sbpl(cwd)

    """
    (version 1)
    (deny default)
    (allow process*)
    (allow network*)
    (allow sysctl-read)
    (allow mach-lookup)
    (allow ipc-posix-shm-read-data)
    (allow file-read* (literal "/"))
    (allow file-read* (subpath "/usr"))
    (allow file-read* (subpath "/bin"))
    (allow file-read* (subpath "/sbin"))
    (allow file-read* (subpath "/System"))
    (allow file-read* (subpath "/Library"))
    (allow file-read* (subpath "/etc"))
    (allow file-read* (subpath "/var"))
    (allow file-read* (subpath "/dev"))
    (allow file-read* (subpath "/opt/homebrew"))
    (allow file-read* (subpath "/usr/local"))
    (allow file-read* (subpath "/private"))
    (allow file-read* file-write* (subpath "/tmp"))
    (allow file-read* file-write* (subpath "/private/tmp"))
    (allow file-read* file-write* (subpath "/var/tmp"))
    #{cwd_rule(escaped_cwd, risk_level)}\
    """
    |> String.trim()
  end

  defp cwd_rule(escaped_cwd, :critical) do
    ~s[(allow file-read* (subpath "#{escaped_cwd}"))]
  end

  defp cwd_rule(escaped_cwd, _risk_level) do
    ~s[(allow file-read* file-write* (subpath "#{escaped_cwd}"))]
  end

  defp escape_sbpl(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
  end
end
