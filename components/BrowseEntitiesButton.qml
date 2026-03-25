import QtQuick

PanelActionButton {
    id: root

    property bool isActive: false

    iconName: isActive ? "expand_less" : "add"
    active: isActive
}
