import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    pluginId: "homeAssistantMonitor"

    StyledText {
        width: parent.width
        text: "Home Assistant Monitor Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure connection to your Home Assistant instance and select entities to monitor."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

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
        defaultValue: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJhZjcxZDk2NGQ2MzI0NzQwYTY2MTA4N2JmYzIwNmY5YiIsImlhdCI6MTc2OTIzNjYxNSwiZXhwIjoyMDg0NTk2NjE1fQ.jj-Bq5xK3wMziR3idi2Evr3iQR4CjyNLEUPI6gPJA_4"
        placeholder: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    }

    StyledText {
        width: parent.width
        text: "Entity Selection"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Click on the widget to browse and select entities to monitor from your Home Assistant instance."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        leftPadding: Theme.spacingM
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    SliderSetting {
        settingKey: "refreshInterval"
        label: "Refresh Interval"
        description: "How often to fetch entity states from Home Assistant"
        defaultValue: 30000
        minimum: 5000
        maximum: 300000
        unit: "ms"
        leftIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "showAttributes"
        label: "Show Detailed Attributes"
        description: "Display additional entity attributes when expanding entities in the widget"
        defaultValue: true
    }

    Rectangle {
        width: parent.width
        height: 1
        color: Theme.outlineVariant
    }

    StyledText {
        width: parent.width
        text: "How to get a Long-Lived Access Token:"
        font.pixelSize: Theme.fontSizeSmall
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "1. Open your Home Assistant instance\n2. Click on your profile (bottom left)\n3. Scroll to 'Long-Lived Access Tokens'\n4. Click 'Create Token'\n5. Copy and paste the token above"
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
        leftPadding: Theme.spacingM
    }
}
