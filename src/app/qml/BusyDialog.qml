import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Kirigami.Dialog {
    id: root

    property var busy: Backend.getObservable("busyState")

    Connections {
        target: Backend
        function onLuaEvent(type, payload) {
            if (root.busy === null) {
                root.busy = Backend.getObservable("busyState")
            }
        }
    }
        
    padding: Kirigami.Units.largeSpacing
    closePolicy: QQC2.Popup.NoAutoClose
    standardButtons: Kirigami.Dialog.NoButton

    Connections {
        target: root.busy
        function onBlockingChanged() {
            if (root.busy.blocking) root.open()
            else root.close()
        }
    }

    customFooterActions: [
        Kirigami.Action {
            text: i18n("Cancel")
            icon.name: "dialog-cancel"
            visible: root.busy !== null && root.busy.cancellable === true
            // onTriggered: Backend.emit("BusyState::CancelRequested", {})
        }
    ]

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        QQC2.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            visible: root.busy === null || root.busy.indicator !== "progress"
            running: visible
        }

        QQC2.ProgressBar {
            Layout.fillWidth: true
            visible: root.busy !== null && root.busy.indicator === "progress"
            from: 0
            to: 1
            value: root.busy !== null ? root.busy.progress : 0
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: root.busy !== null && root.busy.message !== "" ? root.busy.message : i18n("Waiting for the server…")
        }
    }
}