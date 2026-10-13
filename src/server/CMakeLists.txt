# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

add_executable(ktabletop-server
    main.cpp
)
if(WIN32)
    set_target_properties(ktabletop-server PROPERTIES WIN32_EXECUTABLE FALSE)
endif()

target_link_libraries(ktabletop-server PRIVATE
    Qt6::Core
    ktabletop_core
)

install(TARGETS ktabletop-server ${KDE_INSTALL_TARGETS_DEFAULT_ARGS})
