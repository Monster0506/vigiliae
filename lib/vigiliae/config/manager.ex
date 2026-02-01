defmodule Vigiliae.Config.Manager do
  @moduledoc """
  Manages reading and writing the JSON configuration file.
  """

  alias Vigiliae.Config.Target

  @doc """
  Returns the configuration directory path.
  """
  def config_dir do
    Application.get_env(:vigiliae, :config_dir, Path.expand("~/.vigiliae"))
  end

  @doc """
  Returns the full path to the configuration file.
  """
  def config_path do
    Path.join(config_dir(), Application.get_env(:vigiliae, :config_file, "config.json"))
  end

  @doc """
  Returns the full path to the log file.
  """
  def log_path do
    Path.join(config_dir(), "vigiliae.log")
  end

  @doc """
  Ensures the configuration directory exists.
  """
  def ensure_config_dir do
    dir = config_dir()

    case File.mkdir_p(dir) do
      :ok -> {:ok, dir}
      {:error, reason} -> {:error, "Failed to create config directory: #{reason}"}
    end
  end

  @doc """
  Loads the full configuration from the file.
  """
  def load_config do
    with {:ok, _} <- ensure_config_dir(),
         path = config_path(),
         true <- File.exists?(path),
         {:ok, content} <- File.read(path),
         {:ok, data} <- Jason.decode(content) do
      {:ok, data}
    else
      false -> {:ok, %{}}
      {:error, %Jason.DecodeError{}} -> {:error, "Invalid JSON in config file"}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Saves the full configuration to the file.
  """
  def save_config(config) do
    with {:ok, _} <- ensure_config_dir() do
      json = Jason.encode!(config, pretty: true)
      File.write(config_path(), json)
    end
  end

  @doc """
  Gets the default webhook URL from config.
  """
  def get_default_webhook do
    case load_config() do
      {:ok, config} -> Map.get(config, "default_webhook")
      _ -> nil
    end
  end

  @doc """
  Sets the default webhook URL in config.
  """
  def set_default_webhook(webhook_url) do
    with {:ok, config} <- load_config() do
      new_config = Map.put(config, "default_webhook", webhook_url)
      save_config(new_config)
    end
  end

  @doc """
  Loads all targets from the configuration file.
  """
  def load_targets do
    with {:ok, config} <- load_config() do
      targets =
        config
        |> Map.get("targets", [])
        |> Enum.map(&Target.from_map/1)

      {:ok, targets}
    end
  end

  @doc """
  Saves targets to the configuration file (preserves other config).
  """
  def save_targets(targets) do
    with {:ok, config} <- load_config() do
      new_config = Map.put(config, "targets", targets)
      save_config(new_config)
    end
  end

  @doc """
  Adds a new target to the configuration.
  """
  def add_target(attrs) do
    with {:ok, targets} <- load_targets() do
      target = Target.new(attrs)

      if find_target(targets, target.ip) || find_target(targets, target.name) do
        {:error, "Target with this IP or name already exists"}
      else
        :ok = save_targets(targets ++ [target])
        {:ok, target}
      end
    end
  end

  @doc """
  Removes a target by IP or name.
  """
  def remove_target(identifier) do
    with {:ok, targets} <- load_targets() do
      case find_target(targets, identifier) do
        nil ->
          {:error, "Target not found: #{identifier}"}

        target ->
          new_targets = Enum.reject(targets, &(&1.id == target.id))
          :ok = save_targets(new_targets)
          {:ok, target}
      end
    end
  end

  @doc """
  Updates a target by IP or name.
  """
  def update_target(identifier, attrs) do
    with {:ok, targets} <- load_targets() do
      case find_target(targets, identifier) do
        nil ->
          {:error, "Target not found: #{identifier}"}

        target ->
          updated = Target.update(target, attrs)

          new_targets =
            Enum.map(targets, fn t ->
              if t.id == target.id, do: updated, else: t
            end)

          :ok = save_targets(new_targets)
          {:ok, updated}
      end
    end
  end

  @doc """
  Internal: load config for Persistence (alias)
  """
  def load_config_raw, do: load_config()

  @doc """
  Internal: save config for Persistence (alias)
  """
  def save_config_raw(config), do: save_config(config)

  @doc """
  Updates the state (last_state, last_checked) of a target.
  Uses Persistence GenServer if available to prevent race conditions.
  """
  def update_target_state(target_id, updates) when is_map(updates) or is_list(updates) do
    if Process.whereis(Vigiliae.Config.Persistence) do
      # Daemon mode: use GenServer to serialize writes
      Vigiliae.Config.Persistence.update(fn config ->
        targets = Map.get(config, "targets", [])

        new_targets =
          Enum.map(targets, fn t ->
            if t["id"] == target_id do
              updates_map =
                Enum.into(updates, %{}) |> Map.new(fn {k, v} -> {Atom.to_string(k), v} end)

              Map.merge(t, updates_map)
            else
              t
            end
          end)

        Map.put(config, "targets", new_targets)
      end)
    else
      with {:ok, targets} <- load_targets() do
        new_targets =
          Enum.map(targets, fn t ->
            if t.id == target_id do
              # Apply updates to struct
              Enum.reduce(updates, t, fn {k, v}, acc -> Map.put(acc, k, v) end)
            else
              t
            end
          end)

        save_targets(new_targets)
      end
    end
  end

  @doc """
  Updates the last_state of a target.
  """
  def update_last_state(target_id, state) do
    update_target_state(target_id, %{last_state: state})
  end

  @doc """
  Finds a target by IP or name.
  """
  def find_target(targets, identifier) when is_list(targets) do
    Enum.find(targets, fn t ->
      t.ip == identifier || t.name == identifier
    end)
  end

  def find_target(identifier) do
    case load_targets() do
      {:ok, targets} -> find_target(targets, identifier)
      _ -> nil
    end
  end

  @doc """
  Gets a target by ID.
  """
  def get_target_by_id(target_id) do
    case load_targets() do
      {:ok, targets} -> Enum.find(targets, &(&1.id == target_id))
      _ -> nil
    end
  end
end
