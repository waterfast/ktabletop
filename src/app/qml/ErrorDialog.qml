import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop

Kirigami.Dialog {
    id: root

    property var errorState: Backend.getObservable("errorState")

    title: i18n("Error")
    padding: Kirigami.Units.largeSpacing
    standardButtons: Kirigami.Dialog.Ok

    Connections {
        target: root.errorState
        function onActiveChanged() {
            if (root.errorState.active) root.open()
            else root.close()
        }
    }

    // onAccepted: Backend.emit("ErrorState::Dismissed", {})
    // onRejected: Backend.emit("ErrorState::Dismissed", {})

    contentItem: ColumnLayout {
        spacing: Kirigami.Units.largeSpacing

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: Kirigami.Units.iconSizes.large
            implicitHeight: Kirigami.Units.iconSizes.large
            source: root.errorState !== null && root.errorState.kind === "network" ? "network-disconnect" : "dialog-warning"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
            text: root.errorState !== null ? root.errorState.message : ""
        }
    }
}
