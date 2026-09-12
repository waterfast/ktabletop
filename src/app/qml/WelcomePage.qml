import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop


Kirigami.Page {
    id: root

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing * 2

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
                text: i18n("Single player")
                onClicked: singlePlayerDialog.open()
            }

            QQC2.Button { 
                Layout.fillWidth: true
                icon.name: "system-users"
                text: i18n("Multiplayer")
                onClicked: multiplayerDialog.open() 
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

     Kirigami.Dialog {
        id: singlePlayerDialog
        title: i18n("Single Player")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
        onAccepted: Backend.mainViewModel.startSinglePlayer(spUsername.text)

        Kirigami.FormLayout {
            QQC2.TextField {
                id: spUsername
                Kirigami.FormData.label: i18n("Username:")
                text: "Player" + Math.floor(Math.random() * 1000)
            }
        }
    }

    Kirigami.Dialog {
        id: multiplayerDialog
        title: i18n("Multiplayer")
        standardButtons: Kirigami.Dialog.Cancel

        contentItem: ColumnLayout {
            QQC2.TabBar {
                id: mpTabs
                Layout.fillWidth: true
                QQC2.TabButton { text: i18n("Host") }
                QQC2.TabButton { text: i18n("Join") }
            }

            StackLayout {
                currentIndex: mpTabs.currentIndex
                Layout.fillWidth: true

                Kirigami.FormLayout {
                    QQC2.TextField { id: hostUsername; Kirigami.FormData.label: i18n("Username:") }
                    QQC2.SpinBox { id: hostPort; from: 1024; to: 65535; value: 17943; Kirigami.FormData.label: i18n("Port:") }
                    QQC2.Button {
                        text: i18n("Create server")
                        onClicked: { Backend.mainViewModel.hostMultiPlayer(hostUsername.text, hostPort.value); multiplayerDialog.close() }
                    }
                }

                Kirigami.FormLayout {
                    QQC2.TextField { id: joinAddress; Kirigami.FormData.label: i18n("Address:"); placeholderText: "192.168.1.x" }
                    QQC2.SpinBox { id: joinPort; from: 1024; to: 65535; value: 17943; Kirigami.FormData.label: i18n("Port:") }
                    QQC2.TextField { id: joinUsername; Kirigami.FormData.label: i18n("Username:") }
                    QQC2.Button {
                        text: i18n("Join")
                        enabled: joinAddress.text.length > 0
                        onClicked: { Backend.mainViewModel.joinMultiPlayer(joinAddress.text, joinPort.value, joinUsername.text); multiplayerDialog.close() }
                    }
                }
            }
        }
    }

}
