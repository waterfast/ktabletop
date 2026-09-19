import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.OverlayDrawer {
    id: drawer

    modal: false
    width: Kirigami.Units.gridUnit * 4
    height: applicationWindow().height
    edge: Qt.LeftEdge
    parent: QQC2.Overlay.overlay
    x: 0

    Kirigami.Theme.colorSet: Kirigami.Theme.Window
    Kirigami.Theme.inherit: false

    leftPadding: 0
    rightPadding: 0
    topPadding: 0
    bottomPadding: 0

    contentItem: ColumnLayout {
        spacing: 0

        Kirigami.AbstractApplicationHeader {
            Layout.fillWidth: true
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: -1
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AlwaysOff
            QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

            ColumnLayout {
                width: parent.width
                spacing: 0

                Repeater {
                    model: applicationWindow().lobbyNavModel
                    delegate: Kirigami.NavigationTabButton {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        text: modelData.title
                        icon.name: modelData.icon
                        checked: applicationWindow().lobbyNavActive(modelData.name)
                        onClicked: {
                            if (!applicationWindow().lobbyNavActive(modelData.name)) {
                                applicationWindow().switchLobbyNav(index);
                            }
                        }
                    }
                }
            }
        }
    }
}
