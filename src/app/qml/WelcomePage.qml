import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

import org.kde.ktabletop


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
                icon.name: "error"
                text: i18n("Test!")
                onClicked: testDialog.open()
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

    Kirigami.Dialog {
        id: testDialog
        title: "Test"
        preferredWidth: Kirigami.Units.gridUnit * 24
        closePolicy: QQC2.Popup.NoAutoClose

        ListView {
            id: listView

            model: ListModel {
                ListElement { msg: "Hello, world! #1"; type: "info" }
                ListElement { msg: "Connecting to the server..."; type: "info" }
                ListElement { msg: "Hello, world! #3"; type: "error" }
                ListElement { msg: "Hello, world! #4"; type: "error" }
                ListElement { msg: "Hello, world! #5"; type: "info" }
            }
            delegate: QQC2.Control {
                required property var model

                padding: Kirigami.Units.smallSpacing * 2
                implicitWidth: listView.width
                implicitHeight: loader.implicitHeight + padding

                Loader {
                    id: loader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Kirigami.Units.smallSpacing
                    // anchors.verticalCenter: parent.verticalCenter

                    sourceComponent: parent.model.type === "error"
                        ? errorComponent
                        : progressComponent

                    onLoaded: {
                        item.model = parent.model
                    }
                }

                Kirigami.Separator {
                    width: parent.width
                    anchors.bottom: parent.bottom
                }
            }
        }
    }

    Component {
        id: errorComponent

        Kirigami.InlineMessage {
            id: inlineMsg
            property var model

            padding: 4
            implicitWidth: parent ? parent.width : implicitWidth
            type: Kirigami.MessageType.Error
            text: model.msg
            + " This is an error inline message. Use it for example to announce something has gone wrong or that input will not be accepted."
            visible: true
            // showCloseButton: true

            actions: [
                Kirigami.Action {
                    text: "Close"
                    icon.name: "dialog-cancel"
                    onTriggered: console.log("Hello.")
                }
            ]
        }
    }

    Component {
        id: progressComponent

        RowLayout {
            id: row
            implicitWidth: parent ? parent.width : implicitWidth
            property var model
            Kirigami.Icon {
                Layout.alignment: Qt.AlignCenter
                source: "clock"
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                    Layout.fillWidth: true
                    text: row.model.msg
                    wrapMode: Text.Wrap
                }

                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    indeterminate: true
                }
            }
            QQC2.Button {
                Layout.alignment: Qt.AlignCenter
                icon.name: "dialog-cancel"
                text: "Cancel"
            }
        }
    }
}
