import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: root

    required property var entityData
    required property bool detailsExpanded
    required property bool showAttributes

    signal toggleDetails()

    width: parent ? parent.width : implicitWidth
    spacing: Theme.spacingS
    property bool toggleHovered: false

    StyledRect {
        width: parent.width
        height: 32
        visible: root.showAttributes
        radius: Theme.cornerRadius
        color: root.toggleHovered ? Theme.surfaceContainerHigh : Theme.surfaceContainer
        border.width: 1
        border.color: root.detailsExpanded ? Theme.primary : Theme.outline

        Row {
            anchors.fill: parent
            anchors.leftMargin: Theme.spacingM
            anchors.rightMargin: Theme.spacingM
            spacing: Theme.spacingS

            DankIcon {
                name: root.detailsExpanded ? "expand_less" : "expand_more"
                size: 18
                color: root.detailsExpanded ? Theme.primary : Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.detailsExpanded
                    ? I18n.tr("Hide Details", "Entity card hide details button")
                    : I18n.tr("Show Details", "Entity card show details button")
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                color: root.detailsExpanded ? Theme.primary : Theme.surfaceText
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
            onHoveredChanged: root.toggleHovered = hovered
        }

        TapHandler {
            acceptedButtons: Qt.LeftButton
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: root.toggleDetails()
        }
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: root.detailsExpanded && root.showAttributes
        opacity: visible ? 1 : 0
        height: visible ? implicitHeight : 0

        Rectangle {
            width: parent.width
            height: entityIdText.height + Theme.spacingS * 2
            color: Theme.surfaceContainerLowest || Theme.surfaceContainer
            radius: Theme.cornerRadius

            StyledText {
                id: entityIdText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: Theme.spacingS
                anchors.rightMargin: Theme.spacingS
                anchors.verticalCenter: parent.verticalCenter
                text: root.entityData && root.entityData.entityId ? root.entityData.entityId : ""
                font.pixelSize: Theme.fontSizeSmall - 1
                font.family: "monospace"
                color: Theme.surfaceVariantText
                opacity: 0.9
                elide: Text.ElideMiddle
                wrapMode: Text.NoWrap
            }
        }

        Repeater {
            model: {
                if (!root.entityData || !root.entityData.attributes)
                    return [];
                const attrs = root.entityData.attributes;
                const keys = Object.keys(attrs).filter(function(key) {
                    return key !== "friendly_name" && key !== "icon" && key !== "unit_of_measurement";
                });
                return keys.slice(0, 15);
            }

            Rectangle {
                width: parent.width
                height: attrContent.height + Theme.spacingXS * 2
                color: "transparent"
                radius: Theme.cornerRadius

                Row {
                    id: attrContent
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spacingS

                    StyledText {
                        text: modelData.replace(/_/g, " ") + ":"
                        font.pixelSize: Theme.fontSizeSmall
                        font.weight: Font.Medium
                        color: Theme.surfaceVariantText
                        width: Math.min(140, parent.width * 0.35)
                        elide: Text.ElideRight
                        verticalAlignment: Text.AlignTop
                        wrapMode: Text.NoWrap
                    }

                    StyledText {
                        text: {
                            const val = root.entityData.attributes[modelData];
                            if (typeof val === "object")
                                return JSON.stringify(val, null, 2);
                            return String(val);
                        }
                        font.pixelSize: Theme.fontSizeSmall
                        color: Theme.surfaceText
                        width: parent.width - Math.min(140, parent.width * 0.35) - Theme.spacingS
                        wrapMode: Text.Wrap
                        maximumLineCount: 5
                        elide: Text.ElideRight
                    }
                }
            }
        }

        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
    }
}
