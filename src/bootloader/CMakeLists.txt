set(CMAKE_ASM_NASM_OBJECT_FORMAT bin)

add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/boot.bin
        COMMAND nasm
                -f bin
                -I ${CMAKE_CURRENT_SOURCE_DIR}
                ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm
                -o ${CMAKE_BINARY_DIR}/boot.bin
        DEPENDS
                ${CMAKE_CURRENT_SOURCE_DIR}/fat12.inc
                ${CMAKE_CURRENT_SOURCE_DIR}/boot.asm
        COMMENT "Assembling boot"
)

add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/loader.bin
        COMMAND nasm
                -f bin
                -I ${CMAKE_CURRENT_SOURCE_DIR}
                ${CMAKE_CURRENT_SOURCE_DIR}/loader.asm
                -o ${CMAKE_BINARY_DIR}/loader.bin
        DEPENDS
                ${CMAKE_CURRENT_SOURCE_DIR}/loader.asm
                ${CMAKE_CURRENT_SOURCE_DIR}/fat12.inc
        COMMENT "Assembling loader"
)

add_custom_target(
        bootloader ALL
        DEPENDS
                ${CMAKE_BINARY_DIR}/boot.bin
                ${CMAKE_BINARY_DIR}/loader.bin
)