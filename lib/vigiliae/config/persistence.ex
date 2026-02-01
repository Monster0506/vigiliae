defmodule Vigiliae.Config.Persistence do
  @moduledoc """
  GenServer to serialize writes to the configuration file.
  Prevents race conditions when multiple workers update status/last_checked.
  """

  use GenServer
  require Logger

  alias Vigiliae.Config.Manager

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @doc """
  Updates the configuration using a transformation function.
  The function receives the current config map (raw JSON map) and must return the new one.
  """
  def update(transform_fn) do
    GenServer.call(__MODULE__, {:update, transform_fn})
  end

  @doc """
  Forces a reload of the configuration from disk.
  """
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @impl true
  def init(_) do
    # Load initial state from disk
    case Manager.load_config_raw() do
      {:ok, config} ->
        {:ok, config}

      {:error, reason} ->
        Logger.error("Failed to load initial config: #{reason}")
        {:ok, %{}}
    end
  end

  @impl true
  def handle_call({:update, transform_fn}, _from, _state) do
    # Reload from disk to ensure we have the latest version (including manual edits)
    current_config =
      case Manager.load_config_raw() do
        {:ok, cfg} -> cfg
        {:error, _} -> %{}
      end

    new_config = transform_fn.(current_config)

    case Manager.save_config_raw(new_config) do
      :ok ->
        {:reply, :ok, new_config}

      {:error, reason} ->
        Logger.error("Failed to save config: #{reason}")
        {:reply, {:error, reason}, new_config}
    end
  end

  @impl true
  def handle_call(:reload, _from, _state) do
    case Manager.load_config_raw() do
      {:ok, config} ->
        {:reply, :ok, config}

      {:error, reason} ->
        Logger.error("Failed to reload config: #{reason}")
        {:reply, {:error, reason}, %{}}
    end
  end
end
