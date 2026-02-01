defmodule Vigiliae.CLI do
  @moduledoc """
  Main CLI entry point for Vigiliae.
  """

  alias Vigiliae.CLI.Commands

  def main(args) do
    optimus = build_optimus()

    case Optimus.parse!(optimus, args) do
      {[:add], parsed} ->
        Commands.add(parsed)

      {[:list], parsed} ->
        Commands.list(parsed)

      {[:remove], parsed} ->
        Commands.remove(parsed)

      {[:edit], parsed} ->
        Commands.edit(parsed)

      {[:up], parsed} ->
        Commands.start(parsed)

      {[:status], _parsed} ->
        Commands.status()

      {[:down], _parsed} ->
        Commands.down()

      {[:daemon_run], _parsed} ->
        Commands.daemon_run()

      {[:config], parsed} ->
        Commands.config(parsed)

      {[:watch], _parsed} ->
        Commands.watch()

      _ ->
        Optimus.parse!(optimus, ["--help"])
    end
  end

  defp build_optimus do
    Optimus.new!(
      name: "vigiliae",
      description: "Server/IP monitoring tool with Discord notifications",
      version: "0.1.0",
      subcommands: [
        add: [
          name: "add",
          about: "Add a new target to monitor",
          args: [
            ip: [
              value_name: "IP",
              help: "IP address or hostname to monitor",
              required: true
            ]
          ],
          options: [
            name: [
              short: "-n",
              long: "--name",
              help: "Friendly name for the target",
              required: false
            ],
            status: [
              short: "-s",
              long: "--status",
              help: "When to notify: change, up, down, or both (default: change)",
              required: false
            ],
            interval: [
              short: "-i",
              long: "--interval",
              help: "Ping interval in seconds (default: 30)",
              parser: :integer,
              required: false
            ],
            webhook: [
              short: "-w",
              long: "--webhook",
              help: "Discord webhook URL (uses default if not specified)",
              required: false
            ]
          ]
        ],
        list: [
          name: "list",
          about: "List all monitored targets",
          flags: [
            json: [
              short: "-j",
              long: "--json",
              help: "Output as JSON"
            ]
          ]
        ],
        remove: [
          name: "remove",
          about: "Remove a target from monitoring",
          args: [
            identifier: [
              value_name: "IDENTIFIER",
              help: "IP address or name of target to remove",
              required: true
            ]
          ]
        ],
        edit: [
          name: "edit",
          about: "Edit an existing target",
          args: [
            identifier: [
              value_name: "IDENTIFIER",
              help: "IP address or name of target to edit",
              required: true
            ]
          ],
          options: [
            name: [
              short: "-n",
              long: "--name",
              help: "New friendly name",
              required: false
            ],
            status: [
              short: "-s",
              long: "--status",
              help: "When to notify: change, up, down, or both",
              required: false
            ],
            interval: [
              short: "-i",
              long: "--interval",
              help: "New ping interval in seconds",
              parser: :integer,
              required: false
            ],
            webhook: [
              short: "-w",
              long: "--webhook",
              help: "New Discord webhook URL",
              required: false
            ]
          ]
        ],
        up: [
          name: "up",
          about: "Start the monitoring daemon",
          flags: [
            foreground: [
              short: "-f",
              long: "--foreground",
              help: "Run in foreground instead of daemonizing"
            ]
          ]
        ],
        status: [
          name: "status",
          about: "Check if the daemon is running"
        ],
        down: [
          name: "down",
          about: "Stop the monitoring daemon"
        ],
        daemon_run: [
          name: "daemon-run",
          about: "Internal: run the daemon (do not call directly)"
        ],
        config: [
          name: "config",
          about: "View or set configuration options",
          options: [
            default_webhook: [
              short: "-w",
              long: "--default-webhook",
              help: "Set the default Discord webhook URL",
              required: false
            ]
          ]
        ],
        watch: [
          name: "watch",
          about: "Watch daemon logs in real-time"
        ]
      ]
    )
  end
end
