defmodule Vigiliae.CLI.Config do
  @moduledoc """
  Handles the 'config' command to view or set configuration options.
  """

  alias Vigiliae.Config.Manager

  def run(parsed) do
    default_webhook = parsed.options[:default_webhook]

    if default_webhook do
      set_default_webhook(default_webhook)
    else
      show_config()
    end
  end

  defp set_default_webhook(webhook_url) do
    case Manager.set_default_webhook(webhook_url) do
      :ok ->
        IO.puts("Default webhook set successfully.")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end

  defp show_config do
    default_webhook = Manager.get_default_webhook()

    IO.puts("Configuration:")
    IO.puts("  Config directory: #{Manager.config_dir()}")
    IO.puts("  Config file: #{Manager.config_path()}")

    if default_webhook do
      # Truncate for display
      display_url =
        if String.length(default_webhook) > 50 do
          String.slice(default_webhook, 0, 47) <> "..."
        else
          default_webhook
        end

      IO.puts("  Default webhook: #{display_url}")
    else
      IO.puts("  Default webhook: (not set)")
    end
  end
end
