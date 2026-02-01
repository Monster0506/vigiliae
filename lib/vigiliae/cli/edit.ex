defmodule Vigiliae.CLI.Edit do
  @moduledoc """
  Handles the 'edit' command to modify an existing target.
  """

  alias Vigiliae.Config.Manager

  def run(parsed) do
    identifier = parsed.args.identifier

    attrs =
      [
        name: parsed.options[:name],
        status: parsed.options[:status],
        interval: parsed.options[:interval],
        webhook_url: parsed.options[:webhook]
      ]
      |> Enum.filter(fn {_k, v} -> v != nil end)

    if attrs == [] do
      IO.puts("Error: No changes specified. Use --name, --status, --interval, or --webhook.")
      System.halt(1)
    end

    if attrs[:status] && attrs[:status] not in ["change", "up", "down", "both"] do
      IO.puts("Error: status must be 'change', 'up', 'down', or 'both'")
      System.halt(1)
    end

    case Manager.update_target(identifier, attrs) do
      {:ok, target} ->
        display_name = target.name || target.ip
        IO.puts("Updated target: #{display_name}")

        Enum.each(attrs, fn {key, value} ->
          IO.puts("  #{key}: #{value}")
        end)

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end
end
