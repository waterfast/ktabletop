add_library(ktabletop_core STATIC
    server.cpp
    logger.cpp
    game-thread.cpp
    db-thread.cpp
    util.cpp
    stdin-adapter.cpp

    common-lua.cpp
    server-lua.cpp

    packman.cpp
)

qt_add_resources(ktabletop_core "core_resources"
    PREFIX "/sql"
    BASE ${CMAKE_CURRENT_SOURCE_DIR}
    FILES users-init.sql)

target_link_libraries(ktabletop_core PUBLIC
    spdlog::spdlog
    LibGit2::LibGit2
    OpenSSL::Crypto

    Qt6::Sql

    ktabletop_network
    ktabletop_lua
)

target_include_directories(ktabletop_core PUBLIC ${PROJECT_SOURCE_DIR}/src)
