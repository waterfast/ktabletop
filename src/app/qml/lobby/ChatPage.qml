import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.ScrollablePage {
    id: root

    objectName: "Chat"
    title: i18n("Chat")

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.Window

    required property LuaObject d

    titleDelegate: Kirigami.IconTitleSubtitle {
        icon.name: "dialog-messages"
        title: root.title
        subtitle: i18n("%1 player(s) in lobby", root.d.lobbyUsers.length)
    }

    ChatPanel {
        id: chatPanel
        selfId: root.d ? root.d.selfId : -1
    }

    footer: RowLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing

        QQC2.TextField {
            id: input
            Layout.fillWidth: true
            placeholderText: i18n("Write a message…")
            onAccepted: root._send()
        }

        QQC2.Button {
            icon.name: "document-send"
            enabled: input.text.trim().length > 0
            onClicked: root._send()
        }
    }

    Connections {
        target: root.d

        function onSignalEmitted(name, data) {
            if (name === "chatMessage") {
                chatPanel.messages.insert(0, data)
            }
        }
    }

    function _send() {
        const text = input.text.trim();
        if (text.length === 0) return;

        root.d.invoke("sendChatMessage", [text])
        input.text = "";
        input.forceActiveFocus();
    }
}
