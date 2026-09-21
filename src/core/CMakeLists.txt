add_library(ktabletop_core STATIC
    async-context.cpp
    server.cpp
    client.cpp
    logger.cpp
    ktabletop-lua.cpp
    game-thread.cpp

    packman.cpp
)

target_link_libraries(ktabletop_core PUBLIC
    spdlog::spdlog
    LibGit2::LibGit2

    Qt6::Sql

    ktabletop_network
    ktabletop_lua
)

target_include_directories(ktabletop_core PUBLIC ${PROJECT_SOURCE_DIR}/src)
