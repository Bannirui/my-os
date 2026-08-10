cmake_minimum_required(VERSION 3.21)

set(KERNEL_BUILD_DIR ${CMAKE_BINARY_DIR}/kernel)

# head.S → 预处理 → head.s → 汇编 → head.o
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

# C代码 → 编译为目标文件
add_library(kernel_c OBJECT
        main.c
        printk.c
        font.c
)
target_compile_options(kernel_c PRIVATE
        -mcmodel=large -m64
        -fno-builtin -ffreestanding -fno-stack-protector
)
target_include_directories(kernel_c PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# 链接 kernel.elf
add_custom_command(
        OUTPUT ${KERNEL_BUILD_DIR}/kernel.elf
        COMMAND ${CMAKE_COMMAND} -E make_directory ${KERNEL_BUILD_DIR}
        COMMAND ld -b elf64-x86-64
                -T ${CMAKE_SOURCE_DIR}/targets/kernel.lds
                -o ${KERNEL_BUILD_DIR}/kernel.elf
                ${KERNEL_BUILD_DIR}/head.o
                $<TARGET_OBJECTS:kernel_c>
        DEPENDS
                ${KERNEL_BUILD_DIR}/head.o
                kernel_c
                ${CMAKE_SOURCE_DIR}/targets/kernel.lds
        COMMAND_EXPAND_LISTS
        COMMENT "Linking kernel.elf"
)

# 提取 kernel.bin（剥离 ELF 头、调试信息）
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
