defmodule Vigiliae.CLI.Add do
  @moduledoc """
  Handles the 'add' command to add a new monitoring target.
  """

  alias Vigiliae.Config.Manager

  def run(parsed) do
    ip = parsed.args.ip
    name = parsed.options[:name]
    status = parsed.options[:status] || "change"
    interval = parsed.options[:interval] || 30
    webhook = parsed.options[:webhook] || Manager.get_default_webhook()

    unless valid_status?(status) do
      IO.puts("Error: status must be 'change', 'up', 'down', or 'both'")
      System.halt(1)
    end

    unless webhook do
      IO.puts("Error: No webhook provided and no default webhook configured.")

      IO.puts(
        "Use --webhook <url> or set a default with 'vigiliae config --default-webhook <url>'"
      )

      System.halt(1)
    end

    attrs = [
      ip: ip,
      name: name,
      status: status,
      interval: interval,
      webhook_url: webhook
    ]

    case Manager.add_target(attrs) do
      {:ok, target} ->
        display_name = target.name || target.ip
        IO.puts("Added target: #{display_name}")
        IO.puts("  IP: #{target.ip}")
        IO.puts("  Interval: #{target.interval}s")
        IO.puts("  Notify on: #{target.status}")

        if parsed.options[:webhook] == nil do
          IO.puts("  Webhook: (using default)")
        end

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp valid_status?(status) do
    status in ["change", "up", "down", "both"]
  end
end
