defmodule Vigiliae.Daemon.PingWorker do
  @moduledoc """
  Per-target ping worker that monitors a single target.
  """

  use GenServer

  alias Vigiliae.Config.{Manager, Target}
  alias Vigiliae.Ping.Executor
  alias Vigiliae.Webhook.Discord

  require Logger

  def start_link(target) do
    GenServer.start_link(__MODULE__, target)
  end

  @impl true
  def init(target) do
    Logger.info("Starting ping worker for #{Target.display_name(target)}")
    schedule_ping(0)

    {:ok,
     %{
       target: target,
       last_state: target.last_state,
       consecutive_failures: 0
     }}
  end

  @impl true
  def handle_info(:ping, state) do
    # Hot reload: Fetch latest target config to pick up changes
    latest_target =
      case Manager.get_target_by_id(state.target.id) do
        nil ->
          Logger.warning("Target #{state.target.id} not found in config! using cached config.")
          state.target

        updated_target ->
          updated_target
      end

    # Update state with potentially new settings (e.g. interval, status)
    state = %{state | target: latest_target}

    new_state = do_ping(state)

    # Adaptive Interval:
    # If we are in an unconfirmed "down" state (consecutive_failures == 1),
    # retry in half the time to confirm quicker.
    interval = new_state.target.interval

    next_delay =
      if new_state.consecutive_failures == 1 do
        max(1, div(interval, 2))
      else
        interval
      end

    schedule_ping(next_delay * 1000)
    {:noreply, new_state}
  end

  @impl true
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp schedule_ping(delay) do
    Process.send_after(self(), :ping, delay)
  end

  defp do_ping(state) do
    %{target: target, last_state: last_state, consecutive_failures: failures} = state
    result = Executor.ping(target.ip)

    current_state = if result.success, do: "up", else: "down"

    new_failures =
      if result.success do
        0
      else
        failures + 1
      end

    # Confirmed states (down needs 2 consecutive failures to avoid flapping)
    confirmed_down = current_state == "down" and new_failures >= 2
    confirmed_up = current_state == "up"
    # Note: "up" is confirmed immediately, "down" needs 2 checks, so we only act if validated
    state_confirmed = confirmed_up or confirmed_down

    # Check if this is a new state (different from last known state, or first detection)
    is_new_state = state_confirmed and last_state != current_state

    updates = %{last_checked: DateTime.utc_now() |> DateTime.to_iso8601()}

    updates =
      if is_new_state do
        Logger.info("State change for #{Target.display_name(target)}: now #{current_state}")
        Map.put(updates, :last_state, current_state)
      else
        updates
      end

    Manager.update_target_state(target.id, updates)

    should_notify =
      if state_confirmed do
        case target.status do
          "change" -> is_new_state
          "up" -> current_state == "up"
          "down" -> current_state == "down"
          "both" -> true
          _ -> false
        end
      else
        false
      end

    log_msg =
      "Ping #{target.ip}: #{current_state}" <>
        if(result.latency_ms, do: " (#{result.latency_ms}ms)", else: "") <>
        if(should_notify, do: " [NOTIFYING]", else: "") <>
        if(!state_confirmed and current_state == "down", do: " (unconfirmed)", else: "")

    Logger.debug(log_msg)

    if should_notify do
      meta = %{latency_ms: result.latency_ms}
      send_notification(target, current_state, meta)
    end

    new_last = if state_confirmed, do: current_state, else: last_state

    %{state | last_state: new_last, consecutive_failures: new_failures}
  end

  defp send_notification(target, current_state, meta) do
    if target.webhook_url do
      Logger.debug("Sending webhook for #{Target.display_name(target)}...")

      case Discord.notify(target.webhook_url, target, current_state, meta) do
        :ok ->
          Logger.info("Webhook sent for #{Target.display_name(target)}")

        {:error, {:rate_limited, retry_after}} ->
          Logger.warning("Rate limited, retrying in #{retry_after}ms")
          Process.sleep(retry_after)
          Discord.notify(target.webhook_url, target, current_state, meta)

        {:error, reason} ->
          Logger.error("Failed to send webhook: #{reason}")
      end
    end
  end
end
