defmodule Vigiliae.Ping.Result do
  @moduledoc """
  Struct representing the result of a ping operation.
  """

  defstruct [
    :ip,
    :success,
    :latency_ms,
    :error,
    :timestamp
  ]

  @type t :: %__MODULE__{
          ip: String.t(),
          success: boolean(),
          latency_ms: float() | nil,
          error: String.t() | nil,
          timestamp: DateTime.t()
        }

  @doc """
  Creates a successful ping result.
  """
  def success(ip, latency_ms) do
    %__MODULE__{
      ip: ip,
      success: true,
      latency_ms: latency_ms,
      error: nil,
      timestamp: DateTime.utc_now()
    }
  end

  @doc """
  Creates a failed ping result.
  """
  def failure(ip, error \\ "Host unreachable") do
    %__MODULE__{
      ip: ip,
      success: false,
      latency_ms: nil,
      error: error,
      timestamp: DateTime.utc_now()
    }
  end
end
