import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: root

    required property bool visiblePane
    required property bool contentReady
    required property string browseMode
    required property string searchText
    required property var deviceModel
    required property var moreInfoModel
    required property var monitoredEntityIds

    signal requestToggleMonitor(string entityId)
    signal requestBrowseModeChange(string mode)
    signal requestSearchTextChange(string text)

    visible: root.visiblePane

    Rectangle {
        anchors.fill: parent
        radius: Theme.cornerRadius * 1.2
        color: Theme.surfaceContainerLow || Theme.surfaceContainer
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.14)

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spacingM
            spacing: 0

            EntityBrowser {
                width: parent.width
                height: parent.height
                isOpen: true
                browseMode: root.browseMode
                searchText: root.searchText
                deviceModel: root.deviceModel
                moreInfoModel: root.moreInfoModel
                contentReady: root.contentReady
                monitoredEntityIds: root.monitoredEntityIds

                onRequestToggleMonitor: entityId => root.requestToggleMonitor(entityId)
                onRequestBrowseModeChange: mode => root.requestBrowseModeChange(mode)
                onRequestSearchTextChange: text => root.requestSearchTextChange(text)
            }
        }
    }
}
