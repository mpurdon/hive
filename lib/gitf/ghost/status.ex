defmodule GiTF.Ghost.Status do
  @moduledoc """
  Canonical ghost status values and predicates.

  Value macros (`working/0`, `starting/0`, etc.) expand to string literals
  at compile time, so they work in guards, pattern matches, and runtime code.
  Use `require GiTF.Ghost.Status, as: GhostStatus` in consumer modules.
  """

  # Macros — expand to string literals at compile time.
  # Usable in guards, pattern matches, and runtime.
  defmacro working, do: "working"
  defmacro starting, do: "starting"
  defmacro stopped, do: "stopped"
  defmacro crashed, do: "crashed"
  defmacro restarting, do: "restarting"
  defmacro idle, do: "idle"
  defmacro provisioning, do: "provisioning"

  @doc "Returns true if the ghost is actively processing."
  def active?(status), do: status in ["working", "starting"]

  @doc "Returns true if the ghost has reached a terminal state."
  def terminal?(status), do: status in ["stopped", "crashed"]
end
