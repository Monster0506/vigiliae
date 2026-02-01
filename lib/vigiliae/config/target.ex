defmodule Vigiliae.Config.Target do
  @moduledoc """
  Struct representing a monitoring target.
  """

  @derive Jason.Encoder
  defstruct [
    :id,
    :ip,
    :name,
    :webhook_url,
    status: "change",
    interval: 30,
    last_state: nil,
    last_checked: nil,
    created_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          ip: String.t() | nil,
          name: String.t() | nil,
          webhook_url: String.t() | nil,
          status: String.t(),
          interval: pos_integer(),
          last_state: String.t() | nil,
          last_checked: String.t() | nil,
          created_at: String.t() | nil
        }

  @doc """
  Creates a new target with a generated ID.
  """
  def new(attrs) do
    %__MODULE__{
      id: generate_id(),
      ip: attrs[:ip],
      name: attrs[:name],
      webhook_url: attrs[:webhook_url],
      status: attrs[:status] || "change",
      interval: attrs[:interval] || 30,
      last_state: nil,
      last_checked: nil,
      created_at: DateTime.utc_now() |> DateTime.to_iso8601()
    }
  end

  @doc """
  Creates a target from a map (for JSON decoding).
  """
  def from_map(map) when is_map(map) do
    %__MODULE__{
      id: map["id"],
      ip: map["ip"],
      name: map["name"],
      webhook_url: map["webhook_url"],
      status: map["status"] || "change",
      interval: map["interval"] || 30,
      last_state: map["last_state"],
      last_checked: map["last_checked"],
      created_at: map["created_at"]
    }
  end

  @doc """
  Updates a target with new attributes.
  """
  def update(target, attrs) do
    target
    |> maybe_update(:name, attrs[:name])
    |> maybe_update(:webhook_url, attrs[:webhook_url])
    |> maybe_update(:status, attrs[:status])
    |> maybe_update(:interval, attrs[:interval])
  end

  defp maybe_update(target, _key, nil), do: target
  defp maybe_update(target, key, value), do: Map.put(target, key, value)

  @doc """
  Returns the display name for a target (name or IP).
  """
  def display_name(%__MODULE__{name: name, ip: ip}) do
    name || ip
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
