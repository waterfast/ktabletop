import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    objectName: "Chat"
    title: i18n("Chat")

    Kirigami.Theme.inherit: false
    Kirigami.Theme.colorSet: Kirigami.Theme.View

    required property LuaObject d

    contentItem: ChatPanel {
        id: chatPanel
        selfId: root.d ? root.d.selfId : -1
        onSendRequested: text => root.d.invoke("sendChatMessage", [text])
    }

    Connections {
        target: root.d

        function onSignalEmitted(name, data) {
            if (name === "chatMessage") {
                chatPanel.messages.insert(0, data)
            }
        }
    }
}
