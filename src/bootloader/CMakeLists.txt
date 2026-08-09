set(CMAKE_ASM_NASM_OBJECT_FORMAT bin)

add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/boot.bin
        COMMAND nasm
                -f bin
                ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm
                -o ${CMAKE_BINARY_DIR}/boot.bin
        DEPENDS
                ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm
        COMMENT "Assembling bootloader"
)

add_custom_target(
        bootloader ALL
        DEPENDS ${CMAKE_BINARY_DIR}/boot.bin
)