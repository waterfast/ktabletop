add_library(ktabletop_lua STATIC
    c-wrapper.cpp
    lua-binding.cpp
)

target_link_libraries(ktabletop_lua PUBLIC Qt6::Core ${LUA_LIBRARIES})
target_include_directories(ktabletop_lua PUBLIC
    ${PROJECT_SOURCE_DIR}/src
    ${LUA_INCLUDE_DIR}
)