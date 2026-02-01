defmodule Vigiliae.CLI.Commands do
  @moduledoc """
  Command dispatcher for CLI commands.
  """

  alias Vigiliae.CLI.{Add, List, Remove, Edit, Start, Status, Down, Config, Watch}

  defdelegate add(parsed), to: Add, as: :run
  defdelegate list(parsed), to: List, as: :run
  defdelegate remove(parsed), to: Remove, as: :run
  defdelegate edit(parsed), to: Edit, as: :run
  defdelegate start(parsed), to: Start, as: :run
  defdelegate status(), to: Status, as: :run
  defdelegate down(), to: Down, as: :run
  defdelegate daemon_run(), to: Start, as: :daemon_run
  defdelegate config(parsed), to: Config, as: :run
  defdelegate watch(), to: Watch, as: :run
end
