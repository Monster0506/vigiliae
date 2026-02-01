defmodule Vigiliae.Webhook.Discord do
  @moduledoc """
  Discord webhook notification sender.
  """

  @doc """
  Sends a status change notification to Discord.
  `meta` is a map containing extra info like `latency_ms`.
  """
  def notify(webhook_url, target, new_state, meta \\ %{}) do
    payload = build_payload(target, new_state, meta)
    send_raw(webhook_url, payload)
  end

  @doc """
  Sends a raw payload to Discord webhook.
  """
  def send_raw(webhook_url, payload) do
    case Req.post(webhook_url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        :ok

      {:ok, %{status: 429, headers: headers}} ->
        retry_after = get_retry_after(headers)
        {:error, {:rate_limited, retry_after}}

      {:ok, %{status: status, body: body}} ->
        {:error, "Discord returned #{status}: #{inspect(body)}"}

      {:error, reason} ->
        {:error, "Failed to send webhook: #{inspect(reason)}"}
    end
  end

  defp build_payload(target, new_state, meta) do
    display_name = target.name || target.ip
    is_up = new_state == "up"

    {title, color, emoji} =
      if is_up do
        {"Service Restored", 0x2ECC71, "🟢"}
      else
        {"Service Unreachable", 0xE74C3C, "🔴"}
      end

    fields = [
      %{name: "Target", value: "**#{display_name}**", inline: true},
      %{name: "Status", value: "#{emoji} **#{String.upcase(new_state)}**", inline: true}
    ]

    fields =
      if target.name && target.name != target.ip do
        fields ++ [%{name: "IP Address", value: "`#{target.ip}`", inline: true}]
      else
        fields
      end

    fields =
      if meta[:latency_ms] do
        fields ++ [%{name: "Latency", value: "`#{meta.latency_ms} ms`", inline: true}]
      else
        fields
      end

    %{
      embeds: [
        %{
          title: "#{emoji} #{title}",
          description: "Monitor **#{display_name}** has changed state.",
          color: color,
          fields: fields,
          footer: %{
            text: "Vigiliae",
            icon_url: "https://github.com/monster0506.png"
          },
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }
      ]
    }
  end

  defp get_retry_after(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_, value} ->
        case Integer.parse(value) do
          {seconds, _} -> seconds * 1000
          :error -> 5000
        end

      nil ->
        5000
    end
  end
end
