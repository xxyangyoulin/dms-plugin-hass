import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "homeAssistantMonitor"

    StringSetting {
        settingKey: "hassUrl"
        label: "Home Assistant URL"
        description: "The base URL of your Home Assistant instance (e.g., http://homeassistant.local:8123)"
        defaultValue: "http://homeassistant.local:8123"
        placeholder: "http://homeassistant.local:8123"
    }

    StringSetting {
        settingKey: "hassToken"
        label: "Long-Lived Access Token"
        description: "Generate a token from your HA profile page (Settings → Profile → Long-Lived Access Tokens). Keep this secure!"
        defaultValue: ""
        placeholder: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    ToggleSetting {
        settingKey: "showAttributes"
        label: "Show Detailed Attributes"
        description: "Display additional entity attributes when expanding entities in the widget"
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showButtonsOnStatusBar"
        label: "Show Buttons on Status Bar"
        description: "Display control buttons (e.g., switches) for pinned entities on the status bar. When disabled, only the entity state will be shown."
        defaultValue: true
    }
}