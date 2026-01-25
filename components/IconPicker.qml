import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: root

    property string entityId: ""
    property string searchText: ""
    property var customIcons: ({})
    property var commonIcons: []

    signal iconSelected(string iconName)
    signal resetIcon()
    signal close()

    color: Theme.surface
    visible: entityId !== ""

    Column {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            width: parent.width
            height: 50
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spacingS

                Rectangle {
                    width: 36
                    height: 36
                    radius: Theme.cornerRadius
                    color: backMouseArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"

                    DankIcon {
                        anchors.centerIn: parent
                        name: "arrow_back"
                        size: 20
                        color: Theme.surfaceText
                    }

                    MouseArea {
                        id: backMouseArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.close()
                    }
                }

                StyledText {
                    text: I18n.tr("Select Icon", "Icon picker title")
                    font.pixelSize: Theme.fontSizeLarge
                    font.weight: Font.Medium
                    color: Theme.surfaceText
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // Reset button
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                width: resetRow.width + Theme.spacingM * 2
                height: 32
                radius: Theme.cornerRadius
                color: resetMouseArea.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                visible: root.customIcons[root.entityId] !== undefined

                Row {
                    id: resetRow
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        name: "restart_alt"
                        size: 16
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    StyledText {
                        text: I18n.tr("Reset", "Icon picker reset button")
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceVariantText
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    id: resetMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.resetIcon()
                }
            }
        }

        // Search box
        Rectangle {
            width: parent.width - Theme.spacingM * 2
            height: 40
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Theme.cornerRadius
            color: Theme.surfaceContainer
            border.width: iconSearchInput.activeFocus ? 2 : 1
            border.color: iconSearchInput.activeFocus ? Theme.primary : Theme.outline

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
                    id: iconSearchInput
                    width: parent.width - 50
                    height: parent.height
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    verticalAlignment: TextInput.AlignVCenter
                    text: root.searchText
                    onTextChanged: root.searchText = text
                    clip: true

                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        text: I18n.tr("Search icons...", "Icon picker search placeholder")
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeMedium
                        visible: !iconSearchInput.text && !iconSearchInput.activeFocus
                    }
                }

                Rectangle {
                    width: 24
                    height: 24
                    radius: 12
                    color: clearIconSearchMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent"
                    visible: root.searchText.length > 0
                    anchors.verticalCenter: parent.verticalCenter

                    DankIcon {
                        anchors.centerIn: parent
                        name: "close"
                        size: 14
                        color: Theme.surfaceVariantText
                    }

                    MouseArea {
                        id: clearIconSearchMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.searchText = "";
                            iconSearchInput.text = "";
                        }
                    }
                }
            }
        }

        Item { height: Theme.spacingS; width: 1 }

        // Icon grid
        GridView {
            id: iconGridView
            width: parent.width - Theme.spacingM * 2
            height: parent.height - 100
            anchors.horizontalCenter: parent.horizontalCenter
            cellWidth: 48
            cellHeight: 48
            clip: true

            model: {
                const search = root.searchText.toLowerCase();
                if (!search) return root.commonIcons;
                return root.commonIcons.filter(icon => icon.toLowerCase().includes(search));
            }

            delegate: Rectangle {
                width: 44
                height: 44
                radius: Theme.cornerRadius
                color: {
                    const currentIcon = root.customIcons[root.entityId];
                    if (currentIcon === modelData) return Theme.primaryHover;
                    return iconItemMouse.containsMouse ? Theme.surfaceContainerHigh : "transparent";
                }

                DankIcon {
                    anchors.centerIn: parent
                    name: modelData
                    size: 24
                    color: {
                        const currentIcon = root.customIcons[root.entityId];
                        if (currentIcon === modelData) return Theme.primary;
                        return Theme.surfaceText;
                    }
                }

                MouseArea {
                    id: iconItemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.iconSelected(modelData)
                }
            }
        }
    }
}
