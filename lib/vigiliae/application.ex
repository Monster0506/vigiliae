defmodule Vigiliae.Application do
  @moduledoc """
  OTP Application for Vigiliae.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Vigiliae.Config.Persistence
    ]

    opts = [strategy: :one_for_one, name: Vigiliae.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
