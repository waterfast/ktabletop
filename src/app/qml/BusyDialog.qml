import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Item {
    id: root

    readonly property var busy: Backend.getObservable("busyState")
    readonly property bool active: busy !== null && busy.blocking === true
    readonly property bool cancellable: busy !== null && busy.cancellable === true

    visible: active

    // swallow all input so the UI underrneath is truly locked
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onWheel: event => event.accepted = true
    }

    Rectangle {
        anchors.fill: parent
        color: Kirigami.Theme.backgroundColor
        opacity: 0.6
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing

        QQC2.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: root.active
        }

        QQC2.Label {
            Layout.alignment: Qt.AlignHCenter
            text: i18n("Waiting for the server…")
        }

        QQC2.Button {
            Layout.alignment: Qt.AlignHCenter
            visible: root.cancellable
            text: i18n("Cancel")
            icon.name: "dialog-cancel"
            onClicked: Backend.emit("BusyState::CancelRequested", {})
        }
    }
}