import QtQuick

Item {
    id: root

    property bool draggable: true
    property bool clickable: true
    property rect bounds: Qt.rect(-1e5, -1e5, 2e5, 2e5)
    property int returnDuration: 200

    readonly property bool dragging: dragHandler.active
    readonly property bool animating: anim.running
    readonly property alias cursorShape: dragHandler.cursorShape

    signal clicked()
    signal rightClicked()
    signal dragStarted()
    signal dropRequested(real x, real y, var result)
    signal moveFinished(real x, real y)

    property real _originalX: 0
    property real _originalY: 0
    property real _destX: 0
    property real _destY: 0

    TapHandler {
        enabled: root.clickable
        grabPermissions: PointerHandler.TakeOverForbidden
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.NoButton
        gesturePolicy: TapHandler.WithinBounds

        onTapped: (e, button) => {
            if (button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }

        onLongPressed: {
            root.rightClicked();
        }
    }

    DragHandler {
        id: dragHandler
        enabled: root.draggable
        cursorShape: Qt.OpenHandCursor
        grabPermissions: PointerHandler.CanTakeOverFromAnything

        xAxis.minimum: root.bounds.x
        xAxis.maximum: root.bounds.x + root.bounds.width
        yAxis.minimum: root.bounds.y
        yAxis.maximum: root.bounds.y + root.bounds.height

        onActiveChanged: {
            if (active) {
                anim.stop();
                root._originalX = root.x;
                root._originalY = root.y;
                root.dragStarted();
            } else {
                var res = { accepted: true, x: root.x, y: root.y };
                root.dropRequested(res.x, res.y, res);
                root.moveTo(res.accepted ? res.x : root._originalX, res.accepted ? res.y : root._originalY);
            }
        }
    }

    ParallelAnimation {
        id: anim
        running: false

        NumberAnimation {
            target: root; property: "x"
            to: root._destX
            duration: root.returnDuration; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root; property: "y"
            to: root._destY
            duration: root.returnDuration; easing.type: Easing.OutCubic
        }

        onStopped: {
            root.moveFinished(root.x, root.y);
        }
    }

    function moveTo(x, y) {
        if (returnDuration <= 0) {
            root.x = x;
            root.y = y;
            moveFinished(x, y);
            return;
        }
        _destX = x;
        _destY = y;
        anim.restart();
    }

    function destroyOnStop() {
        moveFinished.connect(destroy);
    }
}
