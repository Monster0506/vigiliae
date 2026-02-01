defmodule Vigiliae.CLI.List do
  @moduledoc """
  Handles the 'list' command to display all monitored targets.
  """

  alias Vigiliae.Config.Manager

  def run(parsed) do
    json_output = parsed.flags[:json] || false

    case Manager.load_targets() do
      {:ok, []} ->
        if json_output do
          IO.puts("[]")
        else
          IO.puts("No targets configured.")
          IO.puts("Use 'vigiliae add <ip> --webhook <url>' to add a target.")
        end

      {:ok, targets} ->
        if json_output do
          IO.puts(Jason.encode!(targets, pretty: true))
        else
          print_table(targets)
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp print_table(targets) do
    IO.puts("")

    IO.puts(
      String.pad_trailing("Name/IP", 30) <>
        String.pad_trailing("Status", 10) <> String.pad_trailing("Interval", 10) <> "Last State"
    )

    IO.puts(String.duplicate("-", 70))

    Enum.each(targets, fn target ->
      display = target.name || target.ip

      display =
        if String.length(display) > 28, do: String.slice(display, 0, 25) <> "...", else: display

      last_state = target.last_state || "unknown"

      IO.puts(
        String.pad_trailing(display, 30) <>
          String.pad_trailing(target.status, 10) <>
          String.pad_trailing("#{target.interval}s", 10) <>
          last_state
      )
    end)

    IO.puts("")
    IO.puts("Total: #{length(targets)} target(s)")
  end
end
