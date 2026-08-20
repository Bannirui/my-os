cmake_minimum_required(VERSION 3.21)

set(KERNEL_BUILD_DIR ${CMAKE_BINARY_DIR}/kernel)

# head.S->预处理->head.s->汇编->head.o
add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/head.s
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND gcc -E
                -I ${CMAKE_CURRENT_SOURCE_DIR}
                ${CMAKE_CURRENT_SOURCE_DIR}/head.S
                -o ${KERNEL_BUILD_DIR}/head.s
        DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/head.S
        COMMENT "Preprocessing head.S"
)

add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/head.o
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND as --64
                ${KERNEL_BUILD_DIR}/head.s
                -o ${KERNEL_BUILD_DIR}/head.o
        DEPENDS ${KERNEL_BUILD_DIR}/head.s
        COMMENT "Assembling head.S"
)

# entry.S->预处理->entry.s->汇编->entry.o
add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/entry.s
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND gcc -E
                -I ${CMAKE_CURRENT_SOURCE_DIR}
                ${CMAKE_CURRENT_SOURCE_DIR}/entry.S
                -o ${KERNEL_BUILD_DIR}/entry.s
        DEPENDS
                ${CMAKE_CURRENT_SOURCE_DIR}/entry.S
                ${CMAKE_CURRENT_SOURCE_DIR}/linkage.h
        COMMENT "Preprocessing entry.S"
)

add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/entry.o
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND as --64
                ${KERNEL_BUILD_DIR}/entry.s
                -o ${KERNEL_BUILD_DIR}/entry.o
        DEPENDS ${KERNEL_BUILD_DIR}/entry.s
        COMMENT "Assembling entry.S"
)

# C代码->编译为目标文件
file(GLOB_RECURSE KERNEL_C_SOURCES CONFIGURE_DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/*.c)
file(GLOB_RECURSE KERNEL_C_HEADERS CONFIGURE_DEPENDS
        ${CMAKE_CURRENT_SOURCE_DIR}/*.h)

add_library(kernel_c OBJECT
        ${KERNEL_C_SOURCES}
        ${KERNEL_C_HEADERS}
)
target_compile_options(kernel_c PRIVATE
        -mcmodel=large -m64
        -fno-builtin -ffreestanding -fno-stack-protector
)
target_include_directories(kernel_c PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# 链接 内核程序的链接用链接脚本指定的内存布局
add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/kernel.elf
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND ld -b elf64-x86-64
                -T ${CMAKE_CURRENT_SOURCE_DIR}/kernel.lds
                -o ${KERNEL_BUILD_DIR}/kernel.elf
                ${KERNEL_BUILD_DIR}/head.o
                ${KERNEL_BUILD_DIR}/entry.o
                $<TARGET_OBJECTS:kernel_c>
        DEPENDS
                ${KERNEL_BUILD_DIR}/head.o
                ${KERNEL_BUILD_DIR}/entry.o
                kernel_c
                ${CMAKE_CURRENT_SOURCE_DIR}/kernel.lds
        COMMAND_EXPAND_LISTS
        COMMENT "Linking kernel.elf"
)

# 提取bin 剥离ELF头和调试信息 提取出二进制程序段数据 包括text段 data段和bss段
add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/kernel.bin
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND objcopy -I elf64-x86-64
                -S -R ".eh_frame" -R ".comment"
                -O binary
                ${KERNEL_BUILD_DIR}/kernel.elf
                ${KERNEL_BUILD_DIR}/kernel.bin
        DEPENDS ${KERNEL_BUILD_DIR}/kernel.elf
        COMMENT "Extracting kernel.bin"
)

add_custom_target(kernel ALL
        DEPENDS ${KERNEL_BUILD_DIR}/kernel.bin
)
