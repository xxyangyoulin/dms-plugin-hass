import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins
import "./services"

PluginSettings {
    id: root

    pluginId: "homeAssistantMonitor"

    property string tokenValue: ""
    property bool tokenLoaded: false

    readonly property bool hasUrl: (pluginData.hassUrl || "").trim().length > 0
    readonly property bool hasTokenFile: (pluginData.hassTokenPath || "").trim().length > 0
    readonly property bool hasDirectToken: tokenValue.trim().length > 0
    readonly property bool isConfigured: HomeAssistantService.isConfigured
    readonly property string resolvedStatus: {
        if (!isConfigured)
            return "not_configured";
        return HomeAssistantService.connectionStatus || "offline";
    }
    readonly property color statusColor: {
        switch (resolvedStatus) {
        case "online":
            return Theme.success;
        case "connecting":
        case "degraded":
            return Theme.warning;
        case "auth_error":
        case "offline":
            return Theme.error;
        default:
            return Theme.surfaceVariantText;
        }
    }
    readonly property string statusIcon: {
        switch (resolvedStatus) {
        case "online":
            return "check_circle";
        case "connecting":
            return "sync";
        case "degraded":
            return "warning";
        case "auth_error":
            return "lock";
        case "offline":
            return "cloud_off";
        default:
            return "settings";
        }
    }
    readonly property string statusTitle: {
        switch (resolvedStatus) {
        case "online":
            return I18n.tr("Connected", "Home Assistant settings status");
        case "connecting":
            return I18n.tr("Connecting", "Home Assistant settings status");
        case "degraded":
            return I18n.tr("Connection Unstable", "Home Assistant settings status");
        case "auth_error":
            return I18n.tr("Authentication Failed", "Home Assistant settings status");
        case "offline":
            return I18n.tr("Offline", "Home Assistant settings status");
        default:
            return I18n.tr("Not Configured", "Home Assistant settings status");
        }
    }
    readonly property string statusBody: {
        if (!isConfigured) {
            return I18n.tr("Add a Home Assistant URL and either a token file path or a direct access token.", "Home Assistant settings status hint");
        }
        if (HomeAssistantService.connectionMessage)
            return HomeAssistantService.connectionMessage;
        switch (resolvedStatus) {
        case "online":
            return I18n.tr("The plugin is connected and entity updates should arrive normally.", "Home Assistant settings connected hint");
        case "connecting":
            return I18n.tr("The plugin is authenticating and loading the initial entity state.", "Home Assistant settings connecting hint");
        case "degraded":
            return I18n.tr("The server is reachable, but requests are timing out or reconnecting.", "Home Assistant settings degraded hint");
        case "auth_error":
            return I18n.tr("Check the access token and confirm it still has permission to use the Home Assistant API.", "Home Assistant settings auth hint");
        default:
            return I18n.tr("Verify the server URL, token, and network reachability.", "Home Assistant settings offline hint");
        }
    }

    function loadTokenValue() {
        if (!pluginService)
            return;
        tokenValue = loadValue("hassToken", "");
        tokenLoaded = true;
    }

    function persistTokenValue() {
        if (!tokenLoaded)
            return;
        saveValue("hassToken", tokenValue);
    }

    Component.onCompleted: Qt.callLater(loadTokenValue)
    onPluginServiceChanged: Qt.callLater(loadTokenValue)

    StyledText {
        text: I18n.tr("Home Assistant Monitor", "Home Assistant settings title")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: I18n.tr("Connect DMS to Home Assistant, monitor a curated set of entities, and pin important states to the status bar.", "Home Assistant settings summary")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: I18n.tr("Connection", "Home Assistant settings section")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "hassUrl"
        label: I18n.tr("Home Assistant URL", "Home Assistant URL label")
        description: I18n.tr("Base URL for your Home Assistant instance, for example http://homeassistant.local:8123.", "Home Assistant URL description")
        defaultValue: "http://homeassistant.local:8123"
        placeholder: "http://homeassistant.local:8123"
    }

    StringSetting {
        settingKey: "hassTokenPath"
        label: I18n.tr("Token File Path", "Home Assistant token path label")
        description: I18n.tr("Absolute path to a file containing a long-lived access token. When set, this takes priority over the direct token field below.", "Home Assistant token path description")
        defaultValue: ""
        placeholder: "/run/secrets/hass_token"
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: I18n.tr("Long-Lived Access Token", "Home Assistant token label")
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
            color: Theme.surfaceText
        }

        StyledText {
            text: I18n.tr("Generate a token from Home Assistant Settings -> Profile -> Long-Lived Access Tokens. Leave this empty when using a token file path.", "Home Assistant token help text")
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
            text: root.tokenValue

            onTextEdited: root.tokenValue = text
            onEditingFinished: root.persistTokenValue()
            onActiveFocusChanged: {
                if (!activeFocus) {
                    root.tokenValue = text;
                    root.persistTokenValue();
                }
            }
        }

        StyledText {
            text: root.hasTokenFile
                ? I18n.tr("A token file path is configured, so the direct token field is currently ignored.", "Home Assistant token precedence hint")
                : I18n.tr("The direct token is used only when no token file path is configured.", "Home Assistant token precedence hint")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
            width: parent.width
            wrapMode: Text.WordWrap
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: I18n.tr("Status", "Home Assistant settings section")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StyledRect {
        width: parent.width
        height: statusColumn.implicitHeight + Theme.spacingM * 2
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh
        border.width: 1
        border.color: Qt.rgba(root.statusColor.r, root.statusColor.g, root.statusColor.b, 0.2)

        Column {
            id: statusColumn
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: Theme.spacingS

            Row {
                spacing: Theme.spacingS

                DankIcon {
                    name: root.statusIcon
                    size: Theme.iconSize
                    color: root.statusColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.statusTitle
                    font.pixelSize: Theme.fontSizeMedium
                    font.weight: Font.DemiBold
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            StyledText {
                text: root.statusBody
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                width: parent.width
                wrapMode: Text.WordWrap
            }

            StyledText {
                text: root.hasTokenFile
                    ? I18n.tr("Active credential source: token file", "Home Assistant settings credential source")
                    : (root.hasDirectToken
                        ? I18n.tr("Active credential source: direct token", "Home Assistant settings credential source")
                        : I18n.tr("No credential source configured yet", "Home Assistant settings credential source"))
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
            }
        }
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: I18n.tr("Display", "Home Assistant settings section")
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "showAttributes"
        label: I18n.tr("Show Detailed Attributes", "Home Assistant show attributes setting")
        description: I18n.tr("Allow entity cards to expose extra attributes in the expanded details view.", "Home Assistant show attributes description")
        defaultValue: false
    }

    ToggleSetting {
        settingKey: "showButtonsOnStatusBar"
        label: I18n.tr("Show Status Bar Buttons", "Home Assistant status bar buttons setting")
        description: I18n.tr("Display inline control buttons for pinned entities in the status bar when the entity supports quick actions.", "Home Assistant status bar buttons description")
        defaultValue: true
    }
}
