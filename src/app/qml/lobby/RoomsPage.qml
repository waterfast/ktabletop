import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.ScrollablePage {
    id: root

    objectName: "Rooms"
    title: i18n("Rooms")

    required property LuaObject d

    readonly property var rooms: (root.d && root.d.rooms) ? root.d.rooms : []
    readonly property int userCount: (root.d && root.d.userCount !== undefined) ? root.d.userCount : 0
    readonly property int selfId: (root.d && root.d.selfId !== undefined) ? root.d.selfId : -1

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.View

    actions: [
        Kirigami.Action {
            text: i18n("Refresh rooms")
            icon.name: "view-refresh"
            onTriggered: root.d.invoke("fetchRooms")
        },
        Kirigami.Action {
            text: i18n("Create room")
            icon.name: "list-add"
            onTriggered: createRoomDialog.open()
        },
        Kirigami.Action {
            text: i18n("Exit lobby")
            icon.name: "application-exit"
            onTriggered: quitLobbyDialog.open()
        }
    ]

    titleDelegate: Kirigami.IconTitleSubtitle {
        icon.name: "view-list-details"
        title: root.title
        subtitle: i18n("%1 player(s) online · %2 room(s)", root.userCount, root.rooms.length)
    }

    Kirigami.CardsLayout {
        visible: root.rooms.length > 0
        Repeater {
            model: root.rooms
            delegate: Kirigami.Card {
                id: roomCard
                required property var modelData

                readonly property bool isFull: modelData.userCount >= modelData.capacity
                readonly property bool isMine: modelData.ownerId === root.selfId

                Layout.maximumWidth: Kirigami.Units.gridUnit * 20

                actions: [
                    Kirigami.Action {
                        text: roomCard.isFull ? i18n("Room full") : i18n("join")
                        icon.name: "list-add"
                        enabled: !roomCard.isFull
                        onTriggered: root.d.invoke("joinRoom", [roomCard.modelData.id])
                    }
                ]

                header: RowLayout {
                    spacing: Kirigami.Units.smallSpacing

                    Kirigami.Heading {
                        Layout.fillWidth: true
                        level: 2
                        text: roomCard.modelData.name
                        elide: Text.ElideRight
                    }

                    Kirigami.Badge {
                        visible: roomCard.isMine
                        text: i18n("Your room")
                    }

                    Kirigami.Badge {
                        visible: roomCard.isFull
                        text: i18n("Full")
                        Kirigami.Theme.colorSet: Kirigami.Theme.Complementary
                    }
                }

                contentItem: ColumnLayout {
                    spacing: Kirigami.Units.smallSpacing

                    QQC2.Label {
                        text: i18n("Players: %1/%2", roomCard.modelData.userCount, roomCard.modelData.capacity)
                        opacity: 0.7
                    }

                    QQC2.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: roomCard.modelData.capacity
                        value: roomCard.modelData.userCount
                    }
                }
            }
        }
    }

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        visible: root.rooms.length === 0
        icon.name: "list-add"
        text: i18n("There isn't any room yet")
        explanation: i18n("Create a room to start playing with friends")

        helpfulAction: Kirigami.Action {
            text: i18n("Create room")
            icon.name: "list-add"
            onTriggered: createRoomDialog.open()
        }
    }

    CreateRoomDialog {
        id: createRoomDialog

        d: LuaObject {
            opts: ({ type: "create-room" })
        }

        onAccepted: {
            root.d.invoke("createRoom", [{ name: d.name, capacity: d.capacity }]);
        }
    }

    Kirigami.PromptDialog {
        id: quitLobbyDialog

        title: i18n("Exit lobby")
        subtitle: i18n("Are you sure you want to disconnect from this server?")
        standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel

        onAccepted: root.d.invoke("disconnectFromHost");
    }

    Component.onCompleted: {
        root.d.invoke("fetchRooms")
    }
}
