add_library(ktabletop_network STATIC
    client-socket.cpp
    server-socket.cpp
    user-connection.cpp
    crypto-util.cpp
)

target_link_libraries(ktabletop_network PUBLIC Qt6::Network Qt6::Core OpenSSL::Crypto)
target_include_directories(ktabletop_network PUBLIC ${PROJECT_SOURCE_DIR}/src)