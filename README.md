# Home Assistant Monitor for DankMaterialShell

Home Assistant entity monitoring and management plugin for [DankMaterialShell](https://danklinux.com/)

## Features

- **Status Bar Widget**: Displays Home Assistant status with monitored entity count
- **Expandable Popout**: Shows all monitored entities with their states
- **Entity Management**: Add/remove entities to monitor from the widget
- **Real-time Updates**: Automatic refresh of entity states
- **Entity Controls**: Toggle switches, lights, locks, covers, and more
- **Pinning**: Pin frequently used entities to status bar for quick access
- **Entity Browsing**: Browse and select entities from your Home Assistant instance

## Installation

1. Open Settings -> Plugins
2. Click in "Browse" or "Scan"
3. Install and enable "Home Assistant Monitor"
4. Add "Home Assistant Monitor" to your DankBar widgets list

## Requirements

- Home Assistant instance accessible via HTTP/HTTPS
- Long-lived access token with appropriate permissions

## Configuration

Settings available in plugin settings:

- **Home Assistant URL**: Full URL to your Home Assistant instance (e.g., `http://192.168.1.100:8123`)
- **Access Token**: Long-lived access token from Home Assistant
- **Entity IDs**: Comma-separated list of entity IDs to monitor
- **Refresh Interval**: Time between state updates (default: `5s`)

## Usage

Bar widget shows:
- Home Assistant icon (colored: connected and entities available, no color: no entities, red: connection unavailable)
- Monitored entity count

Click widget to open entity list. Expand entities to access controls and attributes.

## Troubleshooting

If you're having connection issues:
1. Verify your Home Assistant URL is accessible
2. Check that your access token is valid and has appropriate permissions

## Permissions

The plugin requires the following permissions:
- `settings_read`: To read plugin configuration
- `settings_write`: To save plugin settings
- `process`: To execute curl commands for API communication