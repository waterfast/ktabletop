import QtQuick

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Page {
    id: root

    objectName: "Todo"
    title: "TODO"

    required property LuaObject d

    Kirigami.PlaceholderMessage {
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.gridUnit * 4
        icon.name: "question"
        text: "Coming soon"
    }
}
