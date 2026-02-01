# Vigiliae

**Vigiliae** is a daemonized monitoring tool built with Elixir. It continually checks the availability of your services and sends rich statuses updates via Discord Webhooks.


## Installation

Building from source requires Elixir.

```powershell
# Get dependencies
mix deps.get

# Build the executable
mix escript.build
```

This generates the `vigiliae` executable (and `vigiliae.bat` wrapper for Windows).

## Quick Start

1.  **Add a target** (and optional Discord webhook):
    ```powershell
    vigiliae add "My API" --ip 192.168.1.50 --interval 30 --status both --webhook "https://discord.com/api/webhooks/..."
    ```

2.  **Start the daemon**:
    ```powershell
    vigiliae up
    ```

3.  **Check status**:
    ```powershell
    vigiliae list
    ```

4.  **Watch logs**:
    ```powershell
    vigiliae watch
    ```

## Commands

| Command | Description |
| :--- | :--- |
| `up` | Starts the monitoring daemon in the background. |
| `down` | Stops the running daemon. |
| `add` | Adds a new target to monitor. |
| `edit` | Modifies an existing target's settings (interval, webhook, etc). |
| `remove` | Removes a target from configuration. |
| `list` | Lists all targets and their current status. |
| `watch` | Tails the daemon log file in real-time. |
| `config` | Set global defaults (like default webhook URL). |

## Configuration

Configuration is stored in `~/.vigiliae/config.json`. 

You can edit this file manually if preferred. The daemon monitors specific properties like `interval` (seconds) and `status` notification preferences (`up`, `down`, `both`, or `change`).
