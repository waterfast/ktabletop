import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root
    preferredWidth: Kirigami.Units.gridUnit * 32

    signal cancelTask(string key)

    title: {
        if (listModel.count === 0) {
            return i18n("Empty");
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

        let taskStr = "";
        let errorStr = "";
        if (tasks > 0) {
            taskStr = i18np("%1 task", "%1 tasks", tasks);
        }
        if (errors > 0) {
            errorStr = i18np("%1 error", "%1 errors", errors);
        }

        if (taskStr === "") {
            return errorStr;
        } else if (errorStr === "") {
            return taskStr;
        } else {
            return taskStr + ", " + errorStr;
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

            Kirigami.Separator {
                width: parent.width
                anchors.top: parent.top
            }

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
        }
    }

    Component {
        id: errorComponent

        RowLayout {
            property var model
            implicitWidth: parent ? parent.width : implicitWidth
            Kirigami.Icon {
                Layout.alignment: Qt.AlignTop
                source: "dialog-error"
            }

            QQC2.Label {
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

                QQC2.Label {
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
                text: i18n("Cancel")
                visible: row.model?.cancelable ?? false
                onClicked: root.cancelTask(row.model.key)
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
