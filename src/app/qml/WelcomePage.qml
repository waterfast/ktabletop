import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop
import org.kde.ktabletop.settings


Kirigami.Page {
    id: root

    globalToolBarStyle: Kirigami.ApplicationHeaderStyle.None

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.largeSpacing * 2

        Kirigami.Icon {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Kirigami.Units.iconSizes.huge
            Layout.preferredHeight: Kirigami.Units.iconSizes.huge
            source: "org.kde.ktabletop"
        }

        //ColumnLayout {
        //    Layout.alignment: Qt.AlignHCenter
        //    spacing: Kirigami.Units.smallSpacing
            Kirigami.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 1
                text: i18n("KTabletop")
            }

            // QQC2.Label {
            //     Layout.alignment: Qt.AlignHCenter
            //     text: i18n("Your board game platform")
            //     opacity: 0.7
            // }
        //}

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
                text: i18n("Join server")
                onClicked: multiplayerDialog.open()
            }

            QQC2.Button {
                Layout.fillWidth: true
                icon.name: "settings-configure"
                text: i18n("Settings")
                onClicked: KTabletopSettingsView.open()
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
        onAccepted: Backend.mainViewModel.startSinglePlayer(spUsername.text, spPassword.text)
        padding: Kirigami.Units.largeSpacing

        Kirigami.FormLayout {
            QQC2.TextField {
                id: spUsername
                Kirigami.FormData.label: i18n("Username:")
                text: "User" + Math.floor(Math.random() * 1000)
            }
            Kirigami.PasswordField {
                id: spPassword
                Kirigami.FormData.label: i18n("Password:")
            }
        }
    }

    Kirigami.Dialog {
        id: multiplayerDialog
        title: i18n("Join server")
        padding: Kirigami.Units.largeSpacing
        customFooterActions: [
            Kirigami.Action {
                text: i18n("Join")
                icon.name: "media-playback-start"
                enabled: joinAddress.text.length > 0
                onTriggered: {
                    Backend.mainViewModel.joinMultiPlayer(joinAddress.text, joinPort.value, joinUsername.text, joinPassword.text);
                    multiplayerDialog.accepted();
                }
            },
            Kirigami.Action {
                text: i18n("Cancel")
                onTriggered: multiplayerDialog.close()
            }
        ]

        contentItem: Kirigami.FormLayout {
            QQC2.TextField {
                id: joinAddress
                Kirigami.FormData.label: i18n("Server address:")
                placeholderText: "192.168.1.x"
            }
            QQC2.SpinBox {
                id: joinPort
                from: 1024
                to: 65535
                value: 17943
                Kirigami.FormData.label: i18n("Port:")
            }
            QQC2.TextField {
                id: joinUsername
                Kirigami.FormData.label: i18n("Username:")
            }
            Kirigami.PasswordField {
                id: joinPassword
                Kirigami.FormData.label: i18n("Password:")
            }
        }
    }

}
