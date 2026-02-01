defmodule Vigiliae.Daemon.Server do
  @moduledoc """
  Main daemon GenServer that manages ping workers.
  """

  use GenServer

  alias Vigiliae.Config.Manager
  alias Vigiliae.Daemon.PingWorker
  alias Vigiliae.Webhook.Discord

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    Logger.info("Vigiliae daemon starting...")

    case Manager.load_targets() do
      {:ok, targets} ->
        send_startup_notification(targets)
        workers = start_workers(targets)
        Logger.info("Started #{map_size(workers)} ping worker(s)")
        {:ok, %{workers: workers}}

      {:error, reason} ->
        Logger.error("Failed to load targets: #{reason}")
        {:stop, reason}
    end
  end

  defp send_startup_notification(targets) do
    webhook_url = Manager.get_default_webhook()

    if webhook_url do
      target_names = targets |> Enum.map(&(&1.name || &1.ip)) |> Enum.join(", ")

      payload = %{
        embeds: [
          %{
            title: "Vigiliae Daemon Started",
            description: "Monitoring #{length(targets)} target(s)",
            color: 0x3498DB,
            fields: [
              %{name: "Targets", value: target_names || "None", inline: false}
            ],
            timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
          }
        ]
      }

      case Discord.send_raw(webhook_url, payload) do
        :ok -> Logger.info("Sent startup notification")
        {:error, reason} -> Logger.warning("Failed to send startup notification: #{reason}")
      end
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) do
    Logger.warning("Worker #{inspect(pid)} died: #{inspect(reason)}")

    # Find which target this worker was for and restart it
    case find_target_by_pid(state.workers, pid) do
      nil ->
        {:noreply, state}

      target_id ->
        case Manager.get_target_by_id(target_id) do
          nil ->
            new_workers = Map.delete(state.workers, target_id)
            {:noreply, %{state | workers: new_workers}}

          target ->
            Logger.info("Restarting worker for #{target.name || target.ip}")
            Process.sleep(5000)
            {:ok, new_pid} = PingWorker.start_link(target)
            ref = Process.monitor(new_pid)
            new_workers = Map.put(state.workers, target_id, {new_pid, ref})
            {:noreply, %{state | workers: new_workers}}
        end
    end
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp start_workers(targets) do
    targets
    |> Enum.map(fn target ->
      case PingWorker.start_link(target) do
        {:ok, pid} ->
          ref = Process.monitor(pid)
          {target.id, {pid, ref}}

        {:error, reason} ->
          Logger.error("Failed to start worker for #{target.ip}: #{inspect(reason)}")
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Map.new()
  end

  defp find_target_by_pid(workers, pid) do
    Enum.find_value(workers, fn {target_id, {worker_pid, _ref}} ->
      if worker_pid == pid, do: target_id, else: nil
    end)
  end
end
