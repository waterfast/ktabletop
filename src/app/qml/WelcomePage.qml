import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop


Kirigami.Page {
    title: "KTabletop"
    ColumnLayout {
        anchors.centerIn: parent
        QQC2.Button {
            Layout.fillWidth: true
            text: "Single Player"
            onClicked: Backend.mainViewModel.startSinglePlayer()
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Multiple Players"
            onClicked: Backend.mainViewModel.startMultiPlayer()
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Quit"
            onClicked: Qt.quit()
        }
    }
}
