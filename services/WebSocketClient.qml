import QtQuick
import QtWebSockets

Item {
    id: root
    property string url
    property bool active
    property int status: socket.status
    property string errorString: socket.errorString

    signal textMessageReceived(string message)
    signal socketStatusChanged(int status)

    // Expose constants
    readonly property int openStatus: WebSocket.Open
    readonly property int closedStatus: WebSocket.Closed
    readonly property int errorStatus: WebSocket.Error
    readonly property int connectingStatus: WebSocket.Connecting

    WebSocket {
        id: socket
        url: root.url
        active: root.active
        onTextMessageReceived: (message) => root.textMessageReceived(message)
        onStatusChanged: (status) => root.socketStatusChanged(status)
    }

    function sendTextMessage(msg) {
        socket.sendTextMessage(msg)
    }
}
