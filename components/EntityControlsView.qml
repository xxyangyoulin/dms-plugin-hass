import QtQuick
import "./controls"

Item {
    id: root

    required property var entityData
    property bool compactLabels: false

    width: parent ? parent.width : 300
    implicitHeight: controlsLoader.height
    height: implicitHeight

    Loader {
        id: controlsLoader

        width: root.width
        height: item ? Math.max(item.implicitHeight, item.height) : 0
        sourceComponent: {
            if (!root.entityData)
                return null;
            const domain = root.entityData.domain;
            if (domain === "light") return lightControlsComp;
            if (domain === "climate") return climateControlsComp;
            if (domain === "fan") return fanControlsComp;
            if (domain === "cover") return coverControlsComp;
            if (domain === "media_player") return mediaPlayerControlsComp;
            return generalControlsComp;
        }
    }

    Component { id: lightControlsComp; LightControls { entityData: root.entityData; compactLabels: root.compactLabels } }
    Component { id: climateControlsComp; ClimateControls { entityData: root.entityData; compactLabels: root.compactLabels } }
    Component { id: fanControlsComp; FanControls { entityData: root.entityData; compactLabels: root.compactLabels } }
    Component { id: coverControlsComp; CoverControls { entityData: root.entityData; compactLabels: root.compactLabels } }
    Component { id: mediaPlayerControlsComp; MediaPlayerControls { entityData: root.entityData } }
    Component { id: generalControlsComp; GeneralControls { entityData: root.entityData; compactLabels: root.compactLabels } }
}
