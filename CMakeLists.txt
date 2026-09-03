cmake_minimum_required(VERSION 3.20)

set(PICO_BOARD pico2_w CACHE STRING "Target board")
set(PICO_PLATFORM rp2350-riscv CACHE STRING "Target RP2350 Hazard3 core")
# Debian's multilib package uses this prefix while still emitting rv32 code.
set(PICO_GCC_TRIPLE riscv64-unknown-elf CACHE STRING "RISC-V GCC tool prefix")
set(PICOTOOL_FORCE_FETCH_FROM_GIT ON CACHE BOOL
    "Build the Pico SDK matching picotool for UF2 conversion")
# Debian packages Picolibc separately from GCC; its specs provide the rv32
# multilib libc and avoid the unavailable newlib libgloss dependency.
set(PICOLIBC_SPECS
    "--specs=/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs")

if(NOT DEFINED ENV{PICO_SDK_PATH})
    set(PICO_SDK_PATH "${CMAKE_CURRENT_LIST_DIR}/.deps/pico-sdk")
else()
    set(PICO_SDK_PATH "$ENV{PICO_SDK_PATH}")
endif()

include(${PICO_SDK_PATH}/external/pico_sdk_import.cmake)

project(pico2_lcd_hello LANGUAGES ASM C CXX)

pico_sdk_init()

# pico_sdk_init creates the SDK's C targets, so retain Debian's Picolibc specs
# in the global language flags used when those targets are generated.
foreach(language C CXX ASM)
    if(NOT CMAKE_${language}_FLAGS MATCHES "picolibc\\.specs")
        set(CMAKE_${language}_FLAGS "${CMAKE_${language}_FLAGS} ${PICOLIBC_SPECS}"
            CACHE STRING "${language} flags" FORCE)
    endif()
endforeach()

add_executable(pico2_lcd_hello
    src/main.S
)

target_include_directories(pico2_lcd_hello PRIVATE
    ${CMAKE_CURRENT_LIST_DIR}/src
)

target_link_libraries(pico2_lcd_hello PRIVATE
    pico_stdlib
)

pico_enable_stdio_uart(pico2_lcd_hello 0)
pico_enable_stdio_usb(pico2_lcd_hello 0)
pico_add_extra_outputs(pico2_lcd_hello)
