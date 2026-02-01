defmodule Vigiliae.CLI.Remove do
  @moduledoc """
  Handles the 'remove' command to remove a monitoring target.
  """

  alias Vigiliae.Config.Manager

  def run(parsed) do
    identifier = parsed.args.identifier

    case Manager.remove_target(identifier) do
      {:ok, target} ->
        display_name = target.name || target.ip
        IO.puts("Removed target: #{display_name}")

      {:error, reason} ->
        IO.puts("Error: #{reason}")
        System.halt(1)
    end
  end
end
