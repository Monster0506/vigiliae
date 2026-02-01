defmodule Vigiliae.CLI.Down do
  @moduledoc """
  Handles the 'down' command to stop the monitoring daemon.
  """

  alias Vigiliae.Daemon.PidManager

  def run do
    case PidManager.read_pid() do
      {:ok, pid} ->
        if PidManager.process_alive?(pid) do
          stop_daemon(pid)
        else
          IO.puts("Daemon is not running (stale PID file found)")
          PidManager.remove_pid_file()
        end

      {:error, :not_found} ->
        IO.puts("Daemon is not running")

      {:error, reason} ->
        IO.puts("Error checking status: #{reason}")
        System.halt(1)
    end
  end

  defp stop_daemon(pid) do
    case PidManager.kill_process(pid) do
      :ok ->
        PidManager.remove_pid_file()
        IO.puts("Daemon stopped (PID: #{pid})")

      {:error, reason} ->
        IO.puts("Failed to stop daemon: #{reason}")
        System.halt(1)
    end
  end
end
