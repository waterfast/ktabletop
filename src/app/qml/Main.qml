// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigami.layouts as KL

Kirigami.ApplicationWindow {
    width: 240
    height: 400

    pageStack.columnView.columnResizeMode: KL.ColumnView.SingleColumn
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
                    pageStack.push(lobbyPageComponent);
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
                // test ValueChanged
                obj.playerCount = 123;
                // obj.destroy(); // this cause SegFault
            }

            if (tp === "KTabletop::Observable::ValueChanged") {
                // TODO
            }
        }
    }

    Component.onCompleted: {
        console.log(Backend);
    }
}
