import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root
    preferredWidth: Kirigami.Units.gridUnit * 24

    title: {
        if (listModel.count === 0) {
            return "Empty";
        }

        let tasks = 0;
        let errors = 0;
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).type === "task") {
                tasks++;
            } else if (listModel.get(i).type === "error") {
                errors++;
            }
        }

        if (tasks === 0) {
            return `${errors} error(s)`;
        } else if (errors === 0) {
            return `${tasks} task(s)`;
        } else {
            return `${tasks} task(s), ${errors} error(s)`;
        }
    }

    showCloseButton: {
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).type === "task") {
                return false;
            }
        }
        return true;
    }
    closePolicy: showCloseButton ? (QQC2.Popup.CloseOnEscape | QQC2.Popup.CloseOnPressOutside) : QQC2.Popup.NoAutoClose

    ListView {
        id: listView

        model: ListModel { id: listModel }
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

                sourceComponent: parent.model.type === "error" ? errorComponent : progressComponent

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

    Component {
        id: errorComponent

        RowLayout {
            property var model
            implicitWidth: parent ? parent.width : implicitWidth
            Kirigami.Icon {
                source: "dialog-error"
            }

            Text {
                Layout.fillWidth: true
                text: parent.model?.msg ?? ""
                wrapMode: Text.Wrap
            }
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
                    text: row.model?.msg ?? ""
                    wrapMode: Text.Wrap
                }

                QQC2.ProgressBar {
                    Layout.fillWidth: true
                    indeterminate: row.model?.progress === -1
                    from: 0
                    to: 100
                    value: row.model?.progress ?? 0
                }
            }
            QQC2.Button {
                Layout.alignment: Qt.AlignCenter
                icon.name: "dialog-cancel"
                text: "Cancel"
                visible: row.model?.cancelable ?? false
            }
        }
    }

    onClosed: listModel.clear();

    function addError(message: string) {
        if (listModel.count === 0) {
            root.open();
        }
        listModel.insert(0, { msg: message, type: "error" });
    }

    function setTaskData(key: string, message: string, progress: int, cancelable: bool) {
        const dict = { msg: message, type: "task", key, progress, cancelable };
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).key === key) {
                listModel.set(i, dict);
                return;
            }
        }
        if (listModel.count === 0) {
            root.open();
        }
        listModel.insert(0, dict);
    }

    function removeTask(key: string) {
        for (let i = 0; i < listModel.count; i++) {
            if (listModel.get(i).key === key) {
                listModel.remove(i);
                if (listModel.count === 0) {
                    root.close();
                }
                return;
            }
        }
    }
}
