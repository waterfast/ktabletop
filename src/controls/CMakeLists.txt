qt_add_library(ktabletop_controls STATIC)

qt_add_qml_module(ktabletop_controls
    URI org.kde.ktabletop.controls
    # GENERATE_PLUGIN_SOURCE
    QML_FILES
        BasicItem.qml
)
