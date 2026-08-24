// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigami.controls as KControls
import org.kde.kirigami.layouts as KL

Kirigami.ApplicationWindow {
    width: 240
    height: 400

    pageStack.columnView.columnResizeMode: KL.ColumnView.SingleColumn
    pageStack.globalToolBar.showNavigationButtons: pageStack.currentIndex === 0 ? KControls.ApplicationHeaderStyle.ShowForwardButton : KControls.ApplicationHeaderStyle.ShowBackButton | KControls.ApplicationHeaderStyle.ShowForwardButton
    pageStack.initialPage: Kirigami.Page {
        title: "KTabletop"
        ColumnLayout {
            anchors.centerIn: parent
            QQC2.Button {
                Layout.fillWidth: true
                text: "Single Player"
                onClicked: {
                    console.log("Single Player clicked")
                    Backend.startServer(17943);
                    Backend.joinServer("127.0.0.1");
                    // lobby push now via KTabletop::Client::PushLobby from server EnterLobby
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                text: "Multiple Players"
                onClicked: {
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                text: "Quit"
                onClicked: Qt.exit(0)
            }
        }
    }

    Component {
        id: lobbyPageComponent
        LobbyPage {}
    }

    // TODO: move this to other QML file
    Connections {
        target: Backend
        function onLuaEvent(tp, payload) {
            console.log(tp, JSON.stringify(payload));
            if (tp === "KTabletop::Observable::NewObject") {
                const objName = payload._stringId;
                delete payload._stringId;
                const obj = Backend.createPropertyMap(objName, payload);
                obj.playerCount = 123; // test
            }
            if (tp === "KTabletop::Observable::ValueChanged") {
                // TODO
            }
            if (tp === "KTabletop::Client::PushLobby") {
                pageStack.push(lobbyPageComponent); // from server EnterLobby
            }
        }
    }

    Component.onCompleted: {
        console.log(Backend);
    }
}
