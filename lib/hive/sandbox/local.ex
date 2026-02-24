defmodule Hive.Sandbox.Local do
  @moduledoc """
  No-op sandbox adapter. Runs commands directly on the host.
  Used for development or when no isolation tools are available.
  """
  @behaviour Hive.Sandbox

  def wrap_command(cmd, args, opts), do: {cmd, args, opts}
  
  def available?, do: true
  
  def name, do: "local"
end
