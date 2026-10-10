# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

qt_add_library(ktabletop_qml STATIC)
ecm_add_qml_module(ktabletop_qml
    URI org.kde.ktabletop
    GENERATE_PLUGIN_SOURCE
    QML_FILES
        Main.qml
        WelcomePage.qml
        lobby/Sidebar.qml
        lobby/BottomToolbar.qml
        lobby/RoomsPage.qml
        lobby/ChatPage.qml
        lobby/TodoPage.qml
        lobby/CreateRoomDialog.qml
        WaitingRoomPage.qml
        GamePage.qml
        TaskAndErrorDialog.qml
        GameOverDialog.qml
        ChatPanel.qml
    SOURCES
        abstract-catalog.cpp
        i18n-qml-context.cpp
        qml-backend.cpp
        main-view-model.cpp
        lobject-manager.cpp
        lobject-proxy.cpp
    DEPENDENCIES
        # org.kde.kirigamiaddons.formcard
        org.kde.kirigami
)

target_link_libraries(ktabletop_qml PUBLIC
    Qt6::Quick
    KF6::I18n
    KF6::CoreAddons
    KF6::ConfigGui

    ktabletop_controls
    ktabletop_settings
)

target_include_directories(ktabletop_qml PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
)
