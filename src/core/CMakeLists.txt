add_library(ktabletop_core STATIC
    server.cpp
    client.cpp
    common-lua-plugin.cpp
    server-lua-plugin.cpp
)

target_link_libraries(ktabletop_core PUBLIC
    ktabletop_network
    ktabletop_lua
)

target_include_directories(ktabletop_core PUBLIC ${PROJECT_SOURCE_DIR}/src)