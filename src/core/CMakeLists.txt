add_library(ktabletop_core STATIC
    server.cpp
    client.cpp
    logger.cpp
    ktabletop-lua.cpp
    game-thread.cpp
)

target_link_libraries(ktabletop_core PUBLIC
    spdlog::spdlog

    ktabletop_network
    ktabletop_lua
)

target_include_directories(ktabletop_core PUBLIC ${PROJECT_SOURCE_DIR}/src)
