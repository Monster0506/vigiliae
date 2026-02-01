defmodule Vigiliae.CLI.Watch do
  @moduledoc """
  Handles the 'watch' command to tail daemon logs.
  """

  alias Vigiliae.Config.Manager

  def run do
    log_path = Manager.log_path()

    unless File.exists?(log_path) do
      IO.puts("Log file not found: #{log_path}")
      IO.puts("Start the daemon first with 'vigiliae start'")
      System.halt(1)
    end

    IO.puts("Watching logs: #{log_path}")
    IO.puts("Press Ctrl+C to stop.\n")
    IO.puts(String.duplicate("-", 60))

    tail_log(log_path)
  end

  defp tail_log(log_path) do
    # Initial read: Last 50 lines
    initial_offset = initial_print(log_path)
    loop_watch(log_path, initial_offset)
  end

  defp initial_print(log_path) do
    case File.read(log_path) do
      {:ok, content} ->
        lines = String.split(content, "\n")

        # Take last 50 lines (handling potential empty last line from trailing newline)
        lines_to_show =
          lines
          |> Enum.reverse()
          |> Enum.take(50)
          |> Enum.reverse()
          |> Enum.join("\n")

        IO.puts(lines_to_show)
        byte_size(content)

      {:error, _} ->
        0
    end
  end

  defp loop_watch(log_path, offset) do
    Process.sleep(1000)

    new_offset =
      case File.stat(log_path) do
        {:ok, %{size: size}} when size > offset ->
          read_new_content(log_path, offset, size)

        {:ok, %{size: size}} when size < offset ->
          # File was truncated/rotated
          IO.puts("\n--- Log file truncated ---\n")
          read_new_content(log_path, 0, size)

        _ ->
          offset
      end

    loop_watch(log_path, new_offset)
  end

  defp read_new_content(log_path, offset, size) do
    length = size - offset

    case File.open(log_path, [:read, :binary]) do
      {:ok, file} ->
        :file.position(file, offset)

        new_offset =
          case IO.read(file, length) do
            data when is_binary(data) ->
              IO.write(data)
              offset + byte_size(data)

            _ ->
              offset
          end

        File.close(file)
        new_offset

      _ ->
        offset
    end
  end
end
