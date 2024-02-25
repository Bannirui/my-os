cmake_minimum_required(VERSION 3.28.0)
project(my_os)

add_executable(buildup buildup.c)

# 启用汇编语言支持
enable_language(ASM)

# 汇编
add_custom_target(
    as
    ALL
    COMMAND gcc -c ${CMAKE_CURRENT_SOURCE_DIR}/boot16.S -o boot16.o
    COMMAND gcc -c ${CMAKE_CURRENT_SOURCE_DIR}/boot32.S -o boot32.o
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "汇编"
)

# 链接
add_custom_target(
    ld
    ALL
    COMMAND ld -Ttext=0x0 ${CMAKE_CURRENT_BINARY_DIR}/boot16.o -o boot16.elf
    COMMAND ld -Ttext=0x20000 ${CMAKE_CURRENT_BINARY_DIR}/boot32.o -o boot32.elf
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS as
    COMMENT "链接"
)

# binary可执行文件
add_custom_target(
    copy
    ALL
    COMMAND objcopy -O binary boot16.elf boot16.bin
    COMMAND objcopy -O binary boot32.elf boot32.bin
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS ld
    COMMENT "bin可执行文件"
)

# 组装映像
add_custom_target(
    build_boot
    ALL
    COMMAND ./buildup
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS buildup
    COMMENT "组装boot映像文件"
)
