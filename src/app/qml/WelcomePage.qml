import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop


Kirigami.Page {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largespacing * 2

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            source: "org.kde.ktabletop"
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 1
                text: i18n("KTabletop")
            }

            QQC2.Label {
                Layout.alignment: Qt.AlignHCenter
                text: i18n("Your board game platform")
                opacity: 0.7
            }
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.gridUnit * 16
            spacing: Kirigami.Units.smallSpacing

            QQC2.Button {
                Layout.fillWidth: true
                icon.name: "user-identity"
                text: i18n("Sigle player")
                onClicked: Backend.mainViewModel.startSinglePlayer()
            }

            QQC2.Button {
                Layout.fillWidth: true
                icon.name: "system-users"
                text: i18n("Multiplayer")
                onClicked: Backend.mainViewModel.startMultiPlayer()
            }

            Kirigami.Separator {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                Layout.bottomMargin: Kirigami.Units.smallSpacing
            }

            QQC2.Button {
                Layout.fillWidth: true
                flat: true
                icon.name: "application-exit"
                text: i18n("Exit")
                onClicked: Qt.quit()
            }
        }
    }
}
