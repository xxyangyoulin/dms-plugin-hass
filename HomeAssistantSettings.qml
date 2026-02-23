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

    // Custom password field for token
    Column {
        id: tokenSetting
        width: parent.width
        spacing: Theme.spacingS

        property string value: ""
        property bool isInitialized: false

        function findSettings() {
            let item = parent
            while (item) {
                if (item.saveValue !== undefined && item.loadValue !== undefined) {
                    return item
                }
                item = item.parent
            }
            return null
        }

        function loadSettingValue() {
            const settings = findSettings()
            if (settings && settings.pluginService) {
                const loadedValue = settings.loadValue("hassToken", "")
                value = loadedValue
                tokenField.text = loadedValue
                isInitialized = true
            }
        }

        Component.onCompleted: Qt.callLater(loadSettingValue)

        onValueChanged: {
            if (!isInitialized) return
            const settings = findSettings()
            if (settings) {
                settings.saveValue("hassToken", value)
            }
        }

        StyledText {
            text: "Long-Lived Access Token"
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: "Generate a token from your HA profile page (Settings → Profile → Long-Lived Access Tokens). Keep this secure!"
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }

        DankTextField {
            id: tokenField
            width: parent.width
            placeholderText: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
            echoMode: TextInput.Password
            onTextEdited: tokenSetting.value = text
            onEditingFinished: tokenSetting.value = text
            onActiveFocusChanged: {
                if (!activeFocus) tokenSetting.value = text
            }
        }
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
