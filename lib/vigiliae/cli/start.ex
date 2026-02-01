defmodule Vigiliae.CLI.Start do
  @moduledoc """
  Handles the 'start' command to launch the monitoring daemon.
  """

  alias Vigiliae.Config.Manager
  alias Vigiliae.Daemon.PidManager

  def run(parsed) do
    foreground = parsed.flags[:foreground] || false

    case Manager.load_targets() do
      {:ok, []} ->
        IO.puts("No targets configured. Add targets first with 'vigiliae add'.")
        System.halt(1)

      {:ok, _targets} ->
        if foreground do
          run_foreground()
        else
          start_daemon()
        end

      {:error, reason} ->
        IO.puts("Error loading config: #{reason}")
        System.halt(1)
    end
  end

  def daemon_run do
    setup_file_logging()

    case PidManager.write_pid() do
      :ok ->
        log_message("Daemon starting with PID #{System.pid()}")
        run_daemon_mode()

      {:error, reason} ->
        log_message("Failed to write PID file: #{reason}")
        System.halt(1)
    end
  end

  defp run_foreground do
    IO.puts("Starting Vigiliae daemon in foreground...")

    # Start the daemon server specifically.
    case Supervisor.start_child(Vigiliae.Supervisor, Vigiliae.Daemon.Server) do
      {:ok, _pid} ->
        IO.puts("Daemon running. Press Ctrl+C to stop.")
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        IO.puts("Daemon running (already started).")
        Process.sleep(:infinity)

      {:error, reason} ->
        IO.puts("Failed to start daemon: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp run_daemon_mode do
    log_message("Starting Vigiliae daemon...")

    # Start the daemon server specifically. 
    case Supervisor.start_child(Vigiliae.Supervisor, Vigiliae.Daemon.Server) do
      {:ok, _pid} ->
        log_message("Daemon running.")
        Process.sleep(:infinity)

      {:error, {:already_started, _pid}} ->
        log_message("Daemon running (already started).")
        Process.sleep(:infinity)

      {:error, reason} ->
        log_message("Failed to start daemon: #{inspect(reason)}")
        System.halt(1)
    end
  end

  defp setup_file_logging do
    log_path = Manager.log_path()
    Manager.ensure_config_dir()

    # Open log file for appending
    {:ok, file} = File.open(log_path, [:append, :utf8])
    Process.put(:log_file, file)

    # Configure logger to also write to our file
    :logger.add_handler(:file_handler, :logger_std_h, %{
      config: %{file: String.to_charlist(log_path)},
      formatter: {:logger_formatter, %{template: [:time, " [", :level, "] ", :msg, "\n"]}}
    })
  end

  defp log_message(msg) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    line = "[#{timestamp}] #{msg}\n"

    case Process.get(:log_file) do
      nil -> IO.puts(msg)
      file -> IO.write(file, line)
    end
  end

  defp start_daemon do
    case PidManager.read_pid() do
      {:ok, pid} ->
        if PidManager.process_alive?(pid) do
          IO.puts("Daemon is already running (PID: #{pid})")
          System.halt(1)
        else
          PidManager.remove_pid_file()
          do_start_daemon()
        end

      {:error, :not_found} ->
        do_start_daemon()

      {:error, reason} ->
        IO.puts("Error checking daemon status: #{reason}")
        System.halt(1)
    end
  end

  defp do_start_daemon do
    escript_path = find_escript()

    case :os.type() do
      {:win32, _} ->
        start_windows_daemon(escript_path)

      {:unix, _} ->
        start_unix_daemon(escript_path)
    end
  end

  defp find_escript do
    # On Windows, prefer the batch file wrapper if available
    target_name =
      cond do
        match?({:win32, _}, :os.type()) -> "vigiliae.bat"
        true -> "vigiliae"
      end

    case System.find_executable(target_name) do
      nil ->
        cwd = File.cwd!()
        local = Path.join(cwd, target_name)
        fallback = Path.join(cwd, "vigiliae")

        cond do
          File.exists?(local) ->
            local

          File.exists?(fallback) ->
            fallback

          true ->
            IO.puts("Error: Could not find vigiliae executable")
            System.halt(1)
        end

      path ->
        path
    end
  end

  defp start_windows_daemon(escript_path) do
    # Use PowerShell Start-Process
    # -WindowStyle Hidden runs it without a visible window
    args = [
      "-Command",
      "Start-Process",
      "-FilePath",
      "'#{escript_path}'",
      "-ArgumentList",
      "'daemon-run'",
      "-WindowStyle",
      "Hidden"
    ]

    IO.puts("Debug: Executing PowerShell Start-Process for #{escript_path}")

    case System.cmd("powershell", args, stderr_to_stdout: true) do
      {_, 0} ->
        Process.sleep(1000)
        check_daemon_started()

      {output, _} ->
        IO.puts("Failed to start daemon: #{output}")
        System.halt(1)
    end
  end

  defp start_unix_daemon(escript_path) do
    cmd = "nohup #{escript_path} daemon-run > /dev/null 2>&1 &"

    case System.cmd("sh", ["-c", cmd], stderr_to_stdout: true) do
      {_, 0} ->
        Process.sleep(1000)
        check_daemon_started()

      {output, _} ->
        IO.puts("Failed to start daemon: #{output}")
        System.halt(1)
    end
  end

  defp check_daemon_started do
    case PidManager.read_pid() do
      {:ok, pid} ->
        IO.puts("Daemon started (PID: #{pid})")

      {:error, _} ->
        IO.puts("Daemon started")
    end
  end
end
