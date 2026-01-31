import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets
import "../"
import "../../services"

Column {
    id: root
    width: parent.width
    spacing: Theme.spacingM

    required property var entityData

    function getVal(attr, def) {
        if (!entityData) return def;
        if (attr === "state") {
             return HomeAssistantService.getEffectiveValue(entityData.entityId, "state", entityData.state);
        }
        const real = (entityData.attributes && entityData.attributes[attr] !== undefined) 
            ? entityData.attributes[attr] 
            : def;
        return HomeAssistantService.getEffectiveValue(entityData.entityId, attr, real);
    }

    function hasFeature(feature) {
        return HassConstants.supportsFeature(entityData, feature);
    }

    // Media Cover & Info
    RowLayout {
        width: parent.width
        spacing: Theme.spacingM
        visible: entityData.state !== "off" && entityData.state !== "unavailable"

        // Album Art
        Rectangle {
            Layout.preferredWidth: 60
            Layout.preferredHeight: 60
            radius: 8
            color: Theme.surfaceContainerHighest
            clip: true
            visible: coverImage.status === Image.Ready

            Image {
                id: coverImage
                anchors.fill: parent
                source: {
                    const pic = root.getVal("entity_picture", "");
                    if (!pic) return "";
                    if (pic.startsWith("http")) return pic;
                    // Append HA base URL
                    return HomeAssistantService.hassUrl + pic;
                }
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
        }

        // Title & Artist
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            
            StyledText {
                Layout.fillWidth: true
                text: root.getVal("media_title", root.getVal("source", I18n.tr("Unknown Title", "Media player placeholder")))
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
                elide: Text.ElideRight
            }
            
            StyledText {
                Layout.fillWidth: true
                text: root.getVal("media_artist", root.getVal("media_series_title", ""))
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                visible: text !== ""
            }
            
            StyledText {
                Layout.fillWidth: true
                text: root.getVal("app_name", "")
                font.pixelSize: 10
                color: Theme.primary
                elide: Text.ElideRight
                visible: text !== ""
            }
        }
    }

    // Playback Controls
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spacingL
        visible: entityData.state !== "off" && entityData.state !== "unavailable" && entityData.state !== "unknown"

        // Prev
        DankIcon {
            name: "skip_previous"
            size: 24
            color: previousMouse.containsMouse ? Theme.primary : Theme.surfaceText
            opacity: hasFeature(HassConstants.mediaFeature.PREVIOUS_TRACK) ? 1 : 0.3
            
            MouseArea {
                id: previousMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (hasFeature(HassConstants.mediaFeature.PREVIOUS_TRACK)) {
                        HomeAssistantService.callService("media_player", "media_previous_track", entityData.entityId);
                    }
                }
            }
        }

        // Play/Pause/Stop
        DankIcon {
            name: {
                const state = root.getVal("state", "");
                if (state === "playing") return "pause_circle";
                return "play_circle";
            }
            size: 32
            color: playMouse.containsMouse ? Theme.primary : Theme.surfaceText
            
            MouseArea {
                id: playMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    const state = root.getVal("state", "");
                    if (state === "playing") {
                        HomeAssistantService.setOptimisticState(entityData.entityId, "state", "paused");
                        HomeAssistantService.callService("media_player", "media_pause", entityData.entityId);
                    } else {
                        HomeAssistantService.setOptimisticState(entityData.entityId, "state", "playing");
                        HomeAssistantService.callService("media_player", "media_play", entityData.entityId);
                    }
                }
            }
        }

        // Next
        DankIcon {
            name: "skip_next"
            size: 24
            color: nextMouse.containsMouse ? Theme.primary : Theme.surfaceText
            opacity: hasFeature(HassConstants.mediaFeature.NEXT_TRACK) ? 1 : 0.3
            
            MouseArea {
                id: nextMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (hasFeature(HassConstants.mediaFeature.NEXT_TRACK)) {
                        HomeAssistantService.callService("media_player", "media_next_track", entityData.entityId);
                    }
                }
            }
        }
    }
    
    // Volume Control
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: hasFeature(HassConstants.mediaFeature.VOLUME_SET) && entityData.state !== "unavailable" && entityData.state !== "unknown"

        Row {
            width: parent.width
            spacing: Theme.spacingS
            
            DankIcon {
                name: root.getVal("is_volume_muted", false) ? "volume_off" : "volume_up"
                size: 18
                color: Theme.surfaceVariantText
                anchors.verticalCenter: parent.verticalCenter
                
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const muted = root.getVal("is_volume_muted", false);
                        HomeAssistantService.setOptimisticState(entityData.entityId, "is_volume_muted", !muted);
                        HomeAssistantService.callService("media_player", "volume_mute", entityData.entityId, {is_volume_muted: !muted});
                    }
                }
            }
            
            GenericSlider {
                width: parent.width - 24 - Theme.spacingS
                value: root.getVal("volume_level", 0)
                maxValue: 1.0
                step: 0.01
                icon: "" // No icon inside slider
                onChanged: (v) => {
                    HomeAssistantService.setOptimisticState(entityData.entityId, "volume_level", v);
                    HomeAssistantService.callService("media_player", "volume_set", entityData.entityId, {volume_level: v});
                }
                displayValue: Math.round(value * 100) + "%"
            }
        }
    }

    // Offline / Unavailable Message
    StyledText {
        width: parent.width
        text: I18n.tr("Device Unavailable", "Status message")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.surfaceVariantText
        horizontalAlignment: Text.AlignHCenter
        visible: entityData.state === "unavailable" || entityData.state === "unknown"
    }

    // Source Selection
    Column {
        width: parent.width
        spacing: Theme.spacingS
        visible: {
            const list = root.getVal("source_list", []);
            return list && list.length > 0;
        }

        StyledText {
            text: I18n.tr("Source", "Control label")
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        // Use SegmentedControl for few sources, or maybe a dropdown later
        // For now, stick to SegmentedControl if <= 4 sources, else standard list (but SegmentedControl handles array internally)
        
        SegmentedControl {
            width: parent.width
            value: root.getVal("source", "")
            options: root.getVal("source_list", [])
            onSelected: (v) => {
                HomeAssistantService.setOptimisticState(entityData.entityId, "source", v);
                HomeAssistantService.callService("media_player", "select_source", entityData.entityId, {source: v});
            }
        }
    }
}
