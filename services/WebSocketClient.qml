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
    property bool _reopenOnClosed: false
    readonly property bool reconnectPending: _reopenOnClosed

    WebSocket {
        id: socket
        url: root.url
        active: root._internalActive
        onTextMessageReceived: (message) => root.textMessageReceived(message)
        onStatusChanged: (status) => {
            root.socketStatusChanged(status);
            if (status === WebSocket.Closed)
                root._reopenIfPending();
        }
    }

    // Update internal active when external active changes
    onActiveChanged: {
        if (!active)
            _reopenOnClosed = false;
        _internalActive = active;
    }

    function sendTextMessage(msg) {
        socket.sendTextMessage(msg)
    }

    function reconnect() {
        if (!active || _reopenOnClosed)
            return;

        _reopenOnClosed = true;
        _internalActive = false;
        if (socket.status === WebSocket.Closed)
            _reopenIfPending();
    }

    function _reopenIfPending() {
        if (!_reopenOnClosed)
            return;

        _reopenOnClosed = false;
        if (active)
            _internalActive = true;
    }
}
