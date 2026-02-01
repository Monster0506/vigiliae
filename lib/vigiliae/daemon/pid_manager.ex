defmodule Vigiliae.Daemon.PidManager do
  @moduledoc """
  Manages the PID file for the daemon process.
  """

  alias Vigiliae.Config.Manager

  @doc """
  Returns the path to the PID file.
  """
  def pid_path do
    Path.join(Manager.config_dir(), Application.get_env(:vigiliae, :pid_file, "vigiliae.pid"))
  end

  @doc """
  Writes the current process PID to the PID file.
  """
  def write_pid do
    Manager.ensure_config_dir()
    File.write(pid_path(), System.pid())
  end

  @doc """
  Reads the PID from the PID file.
  """
  def read_pid do
    case File.read(pid_path()) do
      {:ok, content} ->
        {:ok, String.trim(content)}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Removes the PID file.
  """
  def remove_pid_file do
    File.rm(pid_path())
  end

  @doc """
  Checks if a process with the given PID is alive.
  """
  def process_alive?(pid) when is_binary(pid) do
    case :os.type() do
      {:win32, _} ->
        check_windows_process(pid)

      {:unix, _} ->
        check_unix_process(pid)
    end
  end

  @doc """
  Kills the process with the given PID.
  """
  def kill_process(pid) when is_binary(pid) do
    case :os.type() do
      {:win32, _} ->
        kill_windows_process(pid)

      {:unix, _} ->
        kill_unix_process(pid)
    end
  end

  defp check_windows_process(pid) do
    case System.cmd("tasklist", ["/FI", "PID eq #{pid}"], stderr_to_stdout: true) do
      {output, 0} ->
        String.contains?(output, pid)

      _ ->
        false
    end
  end

  defp check_unix_process(pid) do
    case System.cmd("kill", ["-0", pid], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  defp kill_windows_process(pid) do
    case System.cmd("taskkill", ["/PID", pid, "/F"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, output}
    end
  end

  defp kill_unix_process(pid) do
    case System.cmd("kill", [pid], stderr_to_stdout: true) do
      {_, 0} -> :ok
      {output, _} -> {:error, output}
    end
  end
end
