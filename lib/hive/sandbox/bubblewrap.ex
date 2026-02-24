defmodule Hive.Sandbox.Bubblewrap do
  @moduledoc """
  Bubblewrap (bwrap) sandbox adapter.
  
  Wraps commands in a lightweight container using Linux namespaces.
  Requires 'bwrap' to be installed and accessible in PATH.
  """
  @behaviour Hive.Sandbox

  def wrap_command(cmd, args, opts) do
    # Basic bubblewrap configuration:
    # - Unshare all namespaces (user, ipc, pid, net, uts, cgroup)
    # - Mount / as read-only
    # - Bind mount /tmp for scratch space
    # - Bind mount the working directory as read-write
    # - Share network (for now, bees need it)
    
    cwd = Keyword.get(opts, :cd, File.cwd!())
    
    bwrap_args = [
      "--unshare-all",
      "--share-net",      # Allow network access
      "--dev", "/dev",
      "--proc", "/proc",
      "--tmpfs", "/tmp",
      "--ro-bind", "/usr", "/usr",
      "--ro-bind", "/bin", "/bin",
      "--ro-bind", "/lib", "/lib",
      "--ro-bind", "/lib64", "/lib64",
      "--ro-bind", "/etc/resolv.conf", "/etc/resolv.conf", # DNS
      "--ro-bind", "/etc/ssl/certs", "/etc/ssl/certs",     # SSL certs
      "--bind", cwd, cwd, # Allow RW access to current working dir
      "--die-with-parent",
      "--new-session",
      "--",
      cmd 
    ] ++ args

    {"bwrap", bwrap_args, opts}
  end
  
  def available? do
    System.find_executable("bwrap") != nil
  end
  
  def name, do: "bubblewrap"
end
