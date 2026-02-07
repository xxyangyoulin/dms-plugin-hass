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

    // Internal property to control reconnection without breaking the external binding
    property bool _internalActive: active

    WebSocket {
        id: socket
        url: root.url
        active: root._internalActive
        onTextMessageReceived: (message) => root.textMessageReceived(message)
        onStatusChanged: (status) => root.socketStatusChanged(status)
    }

    // Update internal active when external active changes
    onActiveChanged: {
        _internalActive = active;
    }

    function sendTextMessage(msg) {
        socket.sendTextMessage(msg)
    }

    function reconnect() {
        // Force a reconnection by toggling the internal active property
        // This doesn't break the external binding
        const wasActive = _internalActive;
        _internalActive = false;
        // Use a small delay to ensure the disconnect is processed
        Qt.callLater(() => {
            _internalActive = wasActive;
        });
    }
}
