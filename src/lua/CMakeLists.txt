add_library(ktabletop_lua STATIC
    lua-helper.cpp
    lua-binding.cpp
    async-context.cpp
)

file(GLOB_RECURSE KTABLETOP_CORE_SCRIPTS CONFIGURE_DEPENDS ${CMAKE_SOURCE_DIR}/scripts/*.lua)
qt_add_resources(ktabletop_lua "scripts"
    PREFIX "/scripts"
    BASE ${CMAKE_SOURCE_DIR}/scripts
    FILES ${KTABLETOP_CORE_SCRIPTS})

target_link_libraries(ktabletop_lua PUBLIC Qt6::Core ${LUA_LIBRARIES})
target_include_directories(ktabletop_lua PUBLIC
    ${PROJECT_SOURCE_DIR}/src
    ${LUA_INCLUDE_DIR}
)
