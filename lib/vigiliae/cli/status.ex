defmodule Vigiliae.CLI.Status do
  @moduledoc """
  Handles the 'status' command to check daemon status.
  """

  alias Vigiliae.Daemon.PidManager

  def run do
    case PidManager.read_pid() do
      {:ok, pid} ->
        if PidManager.process_alive?(pid) do
          IO.puts("Daemon is running (PID: #{pid})")
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
end
