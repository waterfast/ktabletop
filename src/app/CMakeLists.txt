# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

add_subdirectory(qml)

add_executable(ktabletop
    catalog.cpp
    client.cpp
    client-lua.cpp
    qml-backend-controller.cpp
    main.cpp
)

kde_source_files_enable_exceptions(catalog.cpp)

ecm_add_app_icon(KTABLETOP_ICON ICONS ${CMAKE_SOURCE_DIR}/128-logo.png)

target_sources(ktabletop PRIVATE ${KTABLETOP_ICON})

target_link_libraries(ktabletop PRIVATE
    ktabletop_qmlplugin
)
target_link_libraries(ktabletop PUBLIC
    Qt6::Widgets
    Qt6::Quick
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::ConfigGui
    KF6::I18n
    KF6::I18nQml
    KirigamiApp

    ktabletop_qml
    ktabletop_core
)

kconfig_target_kcfg_file(ktabletop FILE ktabletopconfig.kcfg
    CLASS_NAME KTabletopConfig
    MUTATORS
    GENERATE_PROPERTIES
    DEFAULT_VALUE_GETTERS
    PARENT_IN_CONSTRUCTOR
    SINGLETON
    GENERATE_MOC
    QML_REGISTRATION
)
