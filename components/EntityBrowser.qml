import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Widgets
import qs.Services
import "../services"
import "."

Rectangle {
    id: root

    property bool isOpen: false
    property string browseMode: "device"
    property string searchText: ""
    property var deviceModel: []
    property var domainModel: []
    property bool contentReady: false
    readonly property int browserHeaderHeight: 44

    // Signals to communicate with parent
    signal requestToggleMonitor(string entityId)
    signal requestBrowseModeChange(string mode)
    signal requestSearchTextChange(string text)

    // Internal state
    property var expandedGroups: ({})

    function toggleGroupExpanded(groupName) {
        const shouldExpand = !expandedGroups[groupName];
        expandedGroups = shouldExpand ? ({ [groupName]: true }) : ({});
    }

    function isGroupExpanded(groupName) {
        // Auto-expand everything if searching
        if (searchText.trim().length > 0) return true;
        return !!expandedGroups[groupName];
    }

    // Helper to check monitor status via passed ID list
    property var monitoredEntityIds: []

    function isEntityMonitored(entityId) {
        return monitoredEntityIds.indexOf(entityId) >= 0;
    }

    width: parent.width
    height: isOpen ? 400 : 0
    color: "transparent"
    clip: true
    visible: height > 0

    Behavior on height {
        NumberAnimation {
            duration: 250
            easing.type: Easing.InOutCubic
        }
    }

        Column {
            width: parent.width
            height: parent.height
            spacing: Theme.spacingS

        Row {
            width: parent.width
            height: root.browserHeaderHeight
            spacing: Theme.spacingXS

            Rectangle {
                width: parent.width - modeTabs.width - parent.spacing
                height: parent.height
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerLowest || Theme.surfaceContainer
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.primary : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingM
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingS

                    DankIcon {
                        name: "search"
                        size: 18
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 56
                        height: parent.height
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeSmall + 1
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.searchText
                        onTextChanged: root.requestSearchTextChange(text)

                        Text {
                            anchors.fill: parent
                            text: I18n.tr("Search entities...", "Entity browser search placeholder")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeSmall + 1
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    Rectangle {
                        width: 24
                        height: 24
                        radius: 12
                        color: clearMouse.containsMouse ? Theme.surfaceVariantText : "transparent"
                        visible: root.searchText.length > 0
                        anchors.verticalCenter: parent.verticalCenter

                        DankIcon {
                            name: "close"
                            size: 14
                            color: clearMouse.containsMouse ? Theme.surface : Theme.surfaceVariantText
                            anchors.centerIn: parent
                        }

                        MouseArea {
                            id: clearMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.requestSearchTextChange("");
                                searchInput.focus = false;
                            }
                        }
                    }
                }
            }

            Rectangle {
                id: modeTabs
                width: 84
                height: parent.height
                radius: Theme.cornerRadius
                color: Theme.surfaceContainerLowest || Theme.surfaceContainer
                border.width: 1
                border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

                Row {
                    anchors.fill: parent
                    anchors.margins: 4
                    spacing: 4

                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        radius: Theme.cornerRadius * 0.8
                        color: root.browseMode === "device"
                            ? Theme.primaryContainer
                            : "transparent"
                        border.width: root.browseMode === "device" ? 0 : 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "devices"
                                size: 16
                                color: root.browseMode === "device" ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestBrowseModeChange("device")
                        }
                    }

                    Rectangle {
                        width: (parent.width - parent.spacing) / 2
                        height: parent.height
                        radius: Theme.cornerRadius * 0.8
                        color: root.browseMode === "domain"
                            ? Theme.primaryContainer
                            : "transparent"
                        border.width: root.browseMode === "domain" ? 0 : 1
                        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)

                        Row {
                            anchors.centerIn: parent
                            spacing: 4

                            DankIcon {
                                name: "category"
                                size: 16
                                color: root.browseMode === "domain" ? Theme.primary : Theme.surfaceText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.requestBrowseModeChange("domain")
                        }
                    }
                }
            }
        }

        DankListView {
            id: browserListView
            width: parent.width
            height: parent.height - root.browserHeaderHeight - Theme.spacingS
            spacing: Theme.spacingS
            clip: true
            cacheBuffer: 200  // Pre-render items slightly outside viewport
            model: root.contentReady ? (root.browseMode === "device" ? root.deviceModel : root.domainModel) : []

            delegate: Column {
                id: groupColumn
                width: parent ? parent.width : root.width
                spacing: Theme.spacingXS

                property bool isExpanded: root.isGroupExpanded(modelData.name)

                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.cornerRadius * 0.8
                    color: groupMouse.containsMouse
                        ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
                        : (Theme.surfaceContainerLowest || Theme.surfaceContainerLow || Theme.surfaceContainer)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.10)

                    MouseArea {
                        id: groupMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroupExpanded(modelData.name)
                    }

                    Item {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingXS
                        anchors.verticalCenter: parent.verticalCenter
                        height: 24

                        Row {
                            id: groupLeadingRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Theme.spacingS

                            DankIcon {
                                name: groupColumn.isExpanded ? "expand_less" : "expand_more"
                                size: 16
                                color: Theme.primary
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Rectangle {
                                width: 24
                                height: 24
                                radius: 12
                                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
                                anchors.verticalCenter: parent.verticalCenter

                                DankIcon {
                                    anchors.centerIn: parent
                                    name: root.browseMode === "device" ? "devices" : "category"
                                    size: 14
                                    color: Theme.primary
                                }
                            }
                        }

                        Rectangle {
                            id: countBadge
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            height: 22
                            radius: 11
                            width: countLabel.implicitWidth + Theme.spacingS * 2
                            color: Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.08)

                            StyledText {
                                id: countLabel
                                anchors.centerIn: parent
                                text: modelData.entities.length + " " + I18n.tr("items", "Entity browser group count")
                                font.pixelSize: Theme.fontSizeSmall - 2
                                font.weight: Font.Medium
                                color: Theme.surfaceVariantText
                            }
                        }

                        StyledText {
                            anchors.left: groupLeadingRow.right
                            anchors.leftMargin: Theme.spacingS
                            anchors.right: countBadge.left
                            anchors.rightMargin: Theme.spacingS
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.browseMode === "device" ? modelData.name : modelData.name.toUpperCase()
                            font.pixelSize: Theme.fontSizeSmall + 1
                            font.weight: Font.DemiBold
                            color: Theme.surfaceText
                            elide: Text.ElideRight
                        }
                    }
                }

                // Lazy load entities only when group is expanded
                Loader {
                    width: parent.width
                    active: groupColumn.isExpanded
                    visible: status === Loader.Ready
                    asynchronous: false
                    
                    sourceComponent: Column {
                        width: parent ? parent.width - Theme.spacingM : groupColumn.width - Theme.spacingM
                        anchors.right: parent ? parent.right : undefined
                        spacing: Theme.spacingXS

                        Repeater {
                            model: modelData.entities

                            StyledRect {
                                id: entityRowCard
                                width: parent.width
                                height: Math.max(54, textColumn.implicitHeight + Theme.spacingM * 2)
                                radius: Theme.cornerRadius * 1.2
                                color: entityBrowserMouse.containsMouse
                                    ? (Theme.surfaceContainerHighest || Theme.surfaceContainerHigh)
                                    : (Theme.surfaceContainerLow || Theme.surfaceContainer)
                                border.width: 1
                                border.color: isMonitored
                                    ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.25)
                                    : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.18)

                                property bool isMonitored: monitorOverride !== undefined ? !!monitorOverride : actualMonitored
                                property bool isShortcut: HomeAssistantService.isShortcut(modelData.entityId)
                                property bool canBeShortcut: modelData.domain === "button" || modelData.domain === "switch" || modelData.domain === "script" || modelData.domain === "scene"
                                property var monitorOverride: undefined
                                readonly property bool actualMonitored: root.isEntityMonitored(modelData.entityId)

                                function requestMonitorToggle() {
                                    monitorOverride = !isMonitored;
                                    Qt.callLater(function() {
                                        root.requestToggleMonitor(modelData.entityId);
                                    });
                                }

                                onActualMonitoredChanged: {
                                    if (monitorOverride !== undefined && actualMonitored === monitorOverride) {
                                        monitorOverride = undefined;
                                    }
                                }

                                Row {
                                    id: contentRow
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.spacingM
                                    anchors.rightMargin: Theme.spacingM
                                    spacing: Theme.spacingS

                                    // Monitor Checkbox
                                    Rectangle {
                                        id: monitorToggle
                                        width: 20
                                        height: 20
                                        radius: Theme.cornerRadius || 4
                                        color: parent.parent.isMonitored ? Theme.primary : (Theme.surfaceContainerHighest || Theme.surfaceContainerHigh)
                                        border.width: parent.parent.isMonitored ? 0 : 2
                                        border.color: parent.parent.isMonitored ? Theme.primary : Theme.outline
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            name: "check"
                                            size: 14
                                            color: Theme.primaryText
                                            anchors.centerIn: parent
                                            visible: entityRowCard.isMonitored
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: entityRowCard.requestMonitorToggle()
                                        }
                                    }
                                    
                                    // Shortcut Star
                                    Rectangle {
                                        id: shortcutStar
                                        width: 20; height: 20; radius: width / 2
                                        color: "transparent"
                                        visible: parent.parent.canBeShortcut
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        DankIcon {
                                            name: entityRowCard.isShortcut ? "star" : "star_border"
                                            size: 18
                                            color: entityRowCard.isShortcut ? "#FFC107" : Theme.surfaceVariantText // Amber for star
                                            anchors.centerIn: parent
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (entityRowCard.isShortcut) {
                                                    HomeAssistantService.removeShortcut(modelData.entityId);
                                                } else {
                                                    HomeAssistantService.addShortcut(modelData);
                                                    ToastService.showInfo(I18n.tr("Added to shortcuts", "Notification"));
                                                }
                                            }
                                        }
                                    }

                                    DankIcon {
                                        id: entityTypeIcon
                                        name: HassConstants.getIconForDomain(modelData.domain)
                                        size: 18
                                        color: parent.parent.isMonitored ? Theme.primary : Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        id: textColumn
                                        width: contentRow.width
                                            - monitorToggle.width
                                            - entityTypeIcon.width
                                            - (shortcutStar.visible ? shortcutStar.width : 0)
                                            - Theme.spacingS * (shortcutStar.visible ? 3 : 2)
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: modelData.friendlyName
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                        }

                                        StyledText {
                                            text: {
                                                const val = modelData.state || "";
                                                const unit = modelData.unitOfMeasurement || "";
                                                return unit ? `${val} ${unit}` : val;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: entityRowCard.isMonitored ? Theme.primary : Theme.surfaceVariantText
                                            width: parent.width
                                            wrapMode: Text.Wrap
                                            maximumLineCount: 3
                                            elide: Text.ElideRight
                                            visible: text !== ""
                                        }
                                    }
                                }

                                MouseArea {
                                    id: entityBrowserMouse
                                    anchors.fill: parent
                                    anchors.leftMargin: 80 // Leave space for checkboxes and star
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: entityRowCard.requestMonitorToggle()
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
