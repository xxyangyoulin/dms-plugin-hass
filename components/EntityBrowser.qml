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

    // Signals to communicate with parent
    signal requestToggleMonitor(string entityId)
    signal requestBrowseModeChange(string mode)
    signal requestSearchTextChange(string text)

    // Internal state
    property var expandedGroups: ({})

    function toggleGroupExpanded(groupName) {
        let expanded = Object.assign({}, expandedGroups);
        expanded[groupName] = !expanded[groupName];
        expandedGroups = expanded;
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
        spacing: 0

        Rectangle {
            width: parent.width
            height: 1
            color: Theme.outline
            opacity: 0.3
        }

        Column {
            width: parent.width
            spacing: 0

            StyledText {
                width: parent.width
                text: I18n.tr("Browse All Entities", "Entity browser title")
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Medium
                color: Theme.surfaceText
                leftPadding: Theme.spacingM
                topPadding: Theme.spacingS
                bottomPadding: Theme.spacingXS
            }

            // Browse mode toggle
            Row {
                width: parent.width - Theme.spacingM * 2
                anchors.horizontalCenter: parent.horizontalCenter
                height: 32
                spacing: Theme.spacingXS

                Rectangle {
                    width: (parent.width - Theme.spacingXS) / 2
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: root.browseMode === "device" ? Theme.primary : Theme.surfaceContainerHigh
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        DankIcon {
                            name: "devices"
                            size: 16
                            color: root.browseMode === "device" ? Theme.primaryText : Theme.surfaceText
                        }
                        
                        StyledText {
                            text: I18n.tr("Devices", "Browse mode label")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: root.browseMode === "device" ? Theme.primaryText : Theme.surfaceText
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestBrowseModeChange("device")
                    }
                }

                Rectangle {
                    width: (parent.width - Theme.spacingXS) / 2
                    height: parent.height
                    radius: Theme.cornerRadius
                    color: root.browseMode === "domain" ? Theme.primary : Theme.surfaceContainerHigh
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: Theme.spacingXS
                        
                        DankIcon {
                            name: "category"
                            size: 16
                            color: root.browseMode === "domain" ? Theme.primaryText : Theme.surfaceText
                        }
                        
                        StyledText {
                            text: I18n.tr("Domains", "Browse mode label")
                            font.pixelSize: Theme.fontSizeSmall
                            font.weight: Font.Medium
                            color: root.browseMode === "domain" ? Theme.primaryText : Theme.surfaceText
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.requestBrowseModeChange("domain")
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: Theme.spacingXS
                color: "transparent"
            }

            Rectangle {
                width: parent.width - Theme.spacingM * 2
                height: 36
                anchors.horizontalCenter: parent.horizontalCenter
                radius: Theme.cornerRadius
                color: Theme.surfaceContainer
                border.width: searchInput.activeFocus ? 2 : 1
                border.color: searchInput.activeFocus ? Theme.primary : Theme.outline

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spacingS
                    anchors.rightMargin: Theme.spacingS
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "search"
                        size: 18
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: searchInput
                        width: parent.width - 50
                        height: parent.height
                        color: Theme.surfaceText
                        font.pixelSize: Theme.fontSizeMedium
                        verticalAlignment: TextInput.AlignVCenter
                        text: root.searchText
                        onTextChanged: root.requestSearchTextChange(text)

                        Text {
                            anchors.fill: parent
                            text: I18n.tr("Search entities...", "Entity browser search placeholder")
                            color: Theme.surfaceVariantText
                            font.pixelSize: Theme.fontSizeMedium
                            verticalAlignment: Text.AlignVCenter
                            visible: !searchInput.text && !searchInput.activeFocus
                        }
                    }

                    Rectangle {
                        width: 20
                        height: 20
                        radius: 10
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
                width: parent.width
                height: Theme.spacingS
                color: "transparent"
            }
        }

        DankListView {
            id: browserListView
            width: parent.width
            height: parent.height - 135  // Increased to account for mode toggle
            leftMargin: Theme.spacingM
            rightMargin: Theme.spacingM
            spacing: 4
            clip: true
            cacheBuffer: 200  // Pre-render items slightly outside viewport
            model: root.contentReady ? (root.browseMode === "device" ? root.deviceModel : root.domainModel) : []

            delegate: Column {
                id: groupColumn
                width: (parent ? parent.width : root.width) - Theme.spacingM * 2
                spacing: 2

                property bool isExpanded: root.isGroupExpanded(modelData.name)

                    MouseArea {
                        width: parent.width
                        height: headerItem.height
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleGroupExpanded(modelData.name)

                        Item {
                            id: headerItem
                            width: parent.width
                            height: 40

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.spacingS
                                
                                DankIcon {
                                    name: groupColumn.isExpanded ? "expand_less" : "expand_more"
                                    size: 14
                                    color: Theme.primary
                                }

                                DankIcon {
                                    name: root.browseMode === "device" ? "devices" : "category"
                                    size: 14
                                    color: Theme.primary
                                }
                                
                                StyledText {
                                    text: root.browseMode === "device" 
                                        ? modelData.name 
                                        : modelData.name.toUpperCase()
                                    font.pixelSize: Theme.fontSizeSmall
                                    font.weight: Font.Bold
                                    color: Theme.primary
                                    width: Math.min(200, headerItem.width - 150)
                                    elide: Text.ElideRight
                                }
                                
                                StyledText {
                                    text: "(" + modelData.entities.length + ")"
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    visible: root.browseMode === "device"
                                }
                            }

                            // "Add All" button for devices
                            Rectangle {
                                anchors.right: parent.right
                                anchors.rightMargin: Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                width: 60
                                height: 24
                                radius: Theme.cornerRadius
                                color: addAllMouse.containsMouse ? Theme.primary : Theme.surfaceContainerHigh
                                visible: root.browseMode === "device" && modelData.entities.length > 0

                                StyledText {
                                    anchors.centerIn: parent
                                    text: I18n.tr("Add All", "Action label")
                                    font.pixelSize: 10
                                    font.weight: Font.Bold
                                    color: addAllMouse.containsMouse ? Theme.primaryText : Theme.primary
                                }

                                MouseArea {
                                    id: addAllMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                    const idsToAdd = modelData.entities
                                        .map(e => e.entityId)
                                        .filter(id => !root.isEntityMonitored(id));
                                    
                                    if (idsToAdd.length > 0) {
                                        HomeAssistantService.addEntitiesToMonitor(idsToAdd);
                                    }
                                }
                                }
                            }
                        }
                    }

                // Lazy load entities only when group is expanded
                Loader {
                    width: parent.width
                    active: groupColumn.isExpanded
                    visible: status === Loader.Ready
                    asynchronous: true  // Load in background to avoid UI freeze
                    
                    sourceComponent: Column {
                        width: parent ? parent.width : groupColumn.width
                        spacing: 2

                        Repeater {
                            model: modelData.entities

                            StyledRect {
                                width: parent.width
                                height: Math.max(40, contentRow.height + Theme.spacingS * 2)
                                radius: Theme.cornerRadius
                                color: entityBrowserMouse.containsMouse ? Theme.surfaceContainerHigh : Theme.surfaceContainer

                                property bool isMonitored: root.isEntityMonitored(modelData.entityId)
                                property bool isShortcut: HomeAssistantService.isShortcut(modelData.entityId)
                                property bool canBeShortcut: modelData.domain === "button" || modelData.domain === "switch" || modelData.domain === "script" || modelData.domain === "scene"

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
                                        width: 20
                                        height: 20
                                        radius: Theme.cornerRadius || 4
                                        color: parent.parent.isMonitored ? Theme.primary : "transparent"
                                        border.width: 2
                                        border.color: parent.parent.isMonitored ? Theme.primary : Theme.outline
                                        anchors.verticalCenter: parent.verticalCenter

                                        DankIcon {
                                            name: "check"
                                            size: 14
                                            color: Theme.primaryText
                                            anchors.centerIn: parent
                                            visible: parent.parent.parent.isMonitored
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.requestToggleMonitor(modelData.entityId)
                                        }
                                    }
                                    
                                    // Shortcut Star
                                    Rectangle {
                                        width: 20; height: 20; radius: width / 2
                                        color: "transparent"
                                        visible: parent.parent.canBeShortcut
                                        anchors.verticalCenter: parent.verticalCenter
                                        
                                        DankIcon {
                                            name: parent.parent.parent.isShortcut ? "star" : "star_border"
                                            size: 18
                                            color: parent.parent.parent.isShortcut ? "#FFC107" : Theme.surfaceVariantText // Amber for star
                                            anchors.centerIn: parent
                                        }
                                        
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (parent.parent.parent.isShortcut) {
                                                    HomeAssistantService.removeShortcut(modelData.entityId);
                                                } else {
                                                    HomeAssistantService.addShortcut(modelData);
                                                    ToastService.showInfo(I18n.tr("Added to shortcuts", "Notification"));
                                                }
                                            }
                                        }
                                    }

                                    DankIcon {
                                        name: HassConstants.getIconForDomain(modelData.domain)
                                        size: 18
                                        color: Theme.surfaceVariantText
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Column {
                                        width: parent.width - 100
                                        spacing: 2
                                        anchors.verticalCenter: parent.verticalCenter

                                        StyledText {
                                            text: modelData.friendlyName
                                            font.pixelSize: Theme.fontSizeSmall
                                            color: Theme.surfaceText
                                            elide: Text.ElideRight
                                            width: parent.width
                                            wrapMode: Text.NoWrap
                                        }

                                        StyledText {
                                            text: {
                                                const val = modelData.state || "";
                                                const unit = modelData.unitOfMeasurement || "";
                                                return unit ? `${val}${unit}` : val;
                                            }
                                            font.pixelSize: Theme.fontSizeSmall - 1
                                            color: Theme.primary
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
                                    onClicked: root.requestToggleMonitor(modelData.entityId)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}