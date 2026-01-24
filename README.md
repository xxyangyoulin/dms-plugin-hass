# Home Assistant Monitor for DankMaterialShell

![Home Assistant Monitor Preview](./assets/screenshot.png)

Home Assistant entity monitoring and management plugin for [DankMaterialShell](https://danklinux.com/)

## Features

- **Status Bar Widget**: Displays Home Assistant status with monitored entity count
- **Expandable Popout**: Shows all monitored entities with their states
- **Entity Management**: Add/remove entities to monitor from the widget
- **Real-time Updates**: Automatic refresh of entity states
- **Entity Controls**: Toggle switches, lights, locks, covers, and more
- **Attribute Display**: View detailed entity attributes when expanded
- **Pinning**: Pin frequently used entities to status bar for quick access
- **Entity Browsing**: Browse and select entities from your Home Assistant instance
- **Performance Optimized**: Efficient API calls to minimize network overhead
- **Enhanced Error Handling**: Real-time connection status and error reporting
- **Extended Entity Support**: Supports media players, climate controls, input numbers, and more

## Installation

### Using DMS Settings

1. Open Settings -> Plugins
2. Click in "Browse" or "Scan"
3. Install and enable "Home Assistant Monitor"
4. Add "Home Assistant Monitor" to your DankBar widgets list

### Manual Installation

1. Copy plugin directory to `~/.config/DankMaterialShell/plugins/homeAssistantMonitor`
```sh
git clone [repository-url] ~/.config/DankMaterialShell/plugins/homeAssistantMonitor
```
2. Open Settings -> Plugins and click in "Scan"
3. Enable "Home Assistant Monitor"
4. Add "Home Assistant Monitor" to your DankBar widgets list

## Requirements

- Home Assistant instance accessible via HTTP/HTTPS
- Long-lived access token with appropriate permissions
- Network connectivity to your Home Assistant instance

## Configuration

Settings available in plugin settings:

- **Home Assistant URL**: Full URL to your Home Assistant instance (e.g., `http://192.168.1.100:8123`)
- **Access Token**: Long-lived access token from Home Assistant
- **Entity IDs**: Comma-separated list of entity IDs to monitor
- **Refresh Interval**: Time between state updates (default: `3000ms`)
- **Show Attributes**: Toggle display of entity attributes when expanding entities (default: `true`)

## Usage

Bar widget shows:
- Home Assistant icon (colored: connected and entities available, no color: no entities, red: connection unavailable)
- Monitored entity count

Click widget to open entity list. Expand entities to access:
- Detailed attributes
- Entity controls (on/off, brightness, temperature, etc.)
- Pin entities to status bar

### Supported Entity Types

- **Lights**: Toggle, brightness control
- **Switches**: On/off control
- **Sensors**: State monitoring
- **Binary Sensors**: State monitoring
- **Climate**: Temperature control
- **Covers**: Open/close control
- **Locks**: Lock/unlock control
- **Media Players**: Play/pause, volume control
- **Scenes**: Activate scenes
- **Scripts/Automation**: Trigger execution
- **Input Numbers**: Value adjustment
- **Input Booleans**: Toggle state

### Keyboard Navigation

The Home Assistant Monitor supports keyboard navigation when the popout is open:

**Basic Navigation:**
- `Up/Down` or `Ctrl+K/J` or `Ctrl+P/N` or `Tab/Shift+Tab` - Navigate between entities
- `Enter` or `Space` - Expand/collapse the selected entity
- `Left Arrow` or `Ctrl+H` - Collapse the selected entity when in main list
- `Ctrl+R` - Force refresh of all entities

**Entity Actions:**
- `Enter` or `Space` on expanded entity - Toggle the entity state (if controllable)

## Troubleshooting

If you're having connection issues:
1. Verify your Home Assistant URL is accessible
2. Check that your access token is valid and has appropriate permissions
3. Ensure your firewall allows connections to Home Assistant
4. Look for specific error messages in the widget header

## API Permissions

The plugin requires the following permissions:
- `settings_read`: To read plugin configuration
- `settings_write`: To save plugin settings
- `process`: To execute curl commands for API communication