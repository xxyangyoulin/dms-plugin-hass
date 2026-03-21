import QtQuick

IconPicker {
    id: root

    required property var availableIcons

    signal requestSetIcon(string entityId, string iconName)
    signal requestResetIcon(string entityId)
    signal requestClose()

    anchors.fill: parent
    z: 100
    commonIcons: root.availableIcons

    onIconSelected: iconName => {
        root.requestSetIcon(root.entityId, iconName);
        root.requestClose();
    }
    onResetIcon: {
        root.requestResetIcon(root.entityId);
        root.requestClose();
    }
    onClose: root.requestClose()
}
