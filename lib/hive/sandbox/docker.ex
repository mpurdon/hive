defmodule Hive.Sandbox.Docker do
  @moduledoc """
  Docker sandbox adapter.
  
  Runs commands inside a transient Docker container.
  Suitable for macOS/Windows where Bubblewrap is not available.
  """
  @behaviour Hive.Sandbox

  @image "alpine:latest" # Lightweight base image, can be configured

  def wrap_command(cmd, args, opts) do
    cwd = Keyword.get(opts, :cd, File.cwd!())
    
    # Mount the working directory into the container
    docker_args = [
      "run",
      "--rm",               # Remove container after exit
      "-i",                 # Interactive (keep stdin open)
      "-v", "#{cwd}:/workspace",
      "-w", "/workspace",
      "--network", "host",  # Share network
      @image,
      cmd
    ] ++ args

    {"docker", docker_args, opts}
  end
  
  def available? do
    System.find_executable("docker") != nil
  end
  
  def name, do: "docker"
end
