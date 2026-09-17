# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

add_subdirectory(qml)

add_executable(ktabletop-app
    qml-backend-controller.cpp
    main.cpp
)

ecm_add_app_icon(KTABLETOP_ICON ICONS ${CMAKE_SOURCE_DIR}/128-logo.png)

target_sources(ktabletop-app PRIVATE ${KTABLETOP_ICON})

target_link_libraries(ktabletop-app PRIVATE
    ktabletop_qmlplugin
)
target_link_libraries(ktabletop-app PUBLIC
    Qt6::Quick
    KF6::I18n
    KF6::CoreAddons
    KF6::ConfigGui
    Qt::Widgets
    KF6::I18nQml
    KirigamiApp

    ktabletop_qml
    ktabletop_core
)
