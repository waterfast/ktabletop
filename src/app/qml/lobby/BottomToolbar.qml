import QtQuick
import QtQuick.Controls

import org.kde.kirigami as Kirigami

Kirigami.NavigationTabBar {
    id: root

    position: ToolBar.Footer

    actions: [
        Kirigami.Action {
            icon.name: "view-list-details"
            text: i18n("Rooms")
            checked: applicationWindow().lobbyNavActive("Rooms")
            onTriggered: {
                if (!applicationWindow().lobbyNavActive("Rooms")) {
                    applicationWindow().switchLobbyNav(0);
                }
            }
        },
        Kirigami.Action {
            icon.name: "dialog-messages"
            text: i18n("Chat")
            checked: applicationWindow().lobbyNavActive("Chat")
            onTriggered: {
                if (!applicationWindow().lobbyNavActive("Chat")) {
                    applicationWindow().switchLobbyNav(1);
                }
            }
        },
        Kirigami.Action {
            icon.name: "question"
            text: i18n("TODO")
            checked: applicationWindow().lobbyNavActive("Todo")
            onTriggered: {
                if (!applicationWindow().lobbyNavActive("Todo")) {
                    applicationWindow().switchLobbyNav(2);
                }
            }
        },
    ]
}
