defmodule Vigiliae.Ping.Executor do
  @moduledoc """
  Cross-platform ping executor.
  """

  alias Vigiliae.Ping.Result

  @default_count 1
  @default_timeout 5

  @doc """
  Pings the given IP address or hostname.
  Returns a Result struct.
  """
  def ping(ip, opts \\ []) do
    count = Keyword.get(opts, :count, @default_count)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    {cmd, args} = build_command(ip, count, timeout)

    case System.cmd(cmd, args, stderr_to_stdout: true) do
      {output, 0} ->
        case parse_latency(output) do
          {:ok, latency} -> Result.success(ip, latency)
          :error -> Result.success(ip, nil)
        end

      {output, _} ->
        Result.failure(ip, parse_error(output))
    end
  end

  defp build_command(ip, count, timeout_sec) do
    case :os.type() do
      {:win32, _} ->
        {"ping", ["-n", to_string(count), "-w", to_string(timeout_sec * 1000), ip]}

      {:unix, :darwin} ->
        {"ping", ["-c", to_string(count), "-W", to_string(timeout_sec * 1000), ip]}

      {:unix, _} ->
        {"ping", ["-c", to_string(count), "-W", to_string(timeout_sec), ip]}
    end
  end

  defp parse_latency(output) do
    patterns = [
      # Windows: "time=23ms" or "time<1ms"
      ~r/time[=<](\d+(?:\.\d+)?)\s*ms/i,
      # Unix: "time=23.4 ms"
      ~r/time=(\d+(?:\.\d+)?)\s*ms/i,
      # Some systems: "rtt min/avg/max/mdev = 23.456/..."
      ~r/rtt\s+min\/avg\/max\/mdev\s*=\s*[\d.]+\/([\d.]+)/
    ]

    Enum.find_value(patterns, :error, fn pattern ->
      case Regex.run(pattern, output) do
        [_, latency_str] ->
          case Float.parse(latency_str) do
            {latency, _} -> {:ok, latency}
            :error -> nil
          end

        _ ->
          nil
      end
    end)
  end

  defp parse_error(output) do
    cond do
      String.contains?(output, "could not find host") ->
        "Could not resolve hostname"

      String.contains?(output, "Request timed out") ->
        "Request timed out"

      String.contains?(output, "Destination host unreachable") ->
        "Destination host unreachable"

      String.contains?(output, "Network is unreachable") ->
        "Network is unreachable"

      String.contains?(output, "100% packet loss") ->
        "100% packet loss"

      String.contains?(output, "Name or service not known") ->
        "Could not resolve hostname"

      true ->
        "Ping failed"
    end
  end
end
