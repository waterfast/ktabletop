add_library(ktabletop_network STATIC
    client-socket.cpp
    server-socket.cpp
    user-connection.cpp
)

target_link_libraries(ktabletop_network PUBLIC Qt6::Network Qt6::Core)
target_include_directories(ktabletop_network PUBLIC ${PROJECT_SOURCE_DIR}/src)