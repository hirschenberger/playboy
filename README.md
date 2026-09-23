# PLAYBOY
## Baremetal Pico 2 W RISC-V assembly game experiments

An SDK-free, bare-metal RISC-V assembly project for the Raspberry Pi Pico 2 W
and Waveshare Pico-ResTouch-LCD-2.8. The target image owns its RP2350 picobin
metadata, reset entry, stack setup, memory initialization, GPIO, SPI, and
ST7789VW display driver. It does not use Pico SDK, CMake, Ninja, Picolibc, or a
C/C++ runtime.

`mise` provisions and runs the project workflow. It pins Clang, LLD, and LLVM
to version 19; Clang assembles the sources and links the ELF through LLD, while
the configured LLVM version provides the inspection and disassembly tools.
`picotool` turns the finished ELF into a UF2. Flashing and debugging use a
CMSIS-DAP SWD probe through Raspberry Pi's RP2350-capable OpenOCD build.

## Prerequisites

Install [Mise](https://mise.jdx.dev/getting-started.html) once. It is not
available from this host's configured Debian repositories, so use its official
installer:

```sh
curl https://mise.run | sh
~/.local/bin/mise --version
```

For the current shell, add Mise to `PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

Then let mise provision the project host dependencies:

```sh
mise bootstrap packages apply
```

Clang targets `riscv32-unknown-elf` and is invoked with `-march=rv32...` and
`-mabi=ilp32`, producing code for the RP2350's 32-bit Hazard3 RISC-V core.
No target C library is required because the build uses `-nostdlib`.

Connect the CMSIS-DAP probe's SWDIO, SWCLK, and GND signals to the Pico 2
debug connector. The target must be running in RISC-V mode; use BOOTSEL and
`picotool reboot --application --cpu riscv` if it was last started as ARM.

## Build, flash, and debug

```sh
mise run build
mise run inspect
mise run flash
```

The resulting files are:

| File | Purpose |
|---|---|
| `build/playboy.elf` | linked ELF32 RISC-V image |
| `build/playboy.uf2` | RP2350 RISC-V UF2 artifact |
| `build/playboy.map` | flash/RAM linker map |
| `build/playboy.dis` | produced by `mise run disassemble` |

`mise run flash` builds the image and prefers Boot ROM programming when the
Pico is in BOOTSEL mode. It writes the UF2 and selects the RISC-V CPU in that
case. Otherwise it uses SWD to program and verify the ELF. Its OpenOCD log is
written to `build/openocd.log`. If the RISC-V cores cannot be examined (stuck
or in ARM mode), the task automatically falls back to flashing through the
Cortex-M33 core and then retries RISC-V verification. If the fallback also
fails, enter BOOTSEL mode and run `mise run flash`.

To start an interactive GDB session over SWD:

```sh
mise run debug
```

## UART console

UART0 logs are transmitted at 115200 8-N-1 through the Debug Probe. Connect
Pico GP0 (UART0 TX) to the probe's UART RX and connect GND between them. The
debug probe on this host appears as `/dev/ttyACM0`; read the boot message with:

```sh
mise run console
```

`uart_write_string` accepts a NUL-terminated address in `a0`, and
`uart_write_byte` accepts one byte in `a0`. Both may be called from assembly
after `lcd_init`.

The first debugger setup runs `mise run setup-debugger`, which builds Raspberry
Pi's OpenOCD fork in `.tools/openocd-rp2350`; Debian's stock OpenOCD package
does not include the RP2350 RISC-V target configuration.

## Hardware

Mount the Pico 2 W directly on the LCD with its USB connector facing the same
direction as the LCD microSD slot.

| GPIO | Signal | Use |
|---:|---|---|
| GP0 | UART0 TX | Debug Probe console output |
| GP1 | UART0 RX | optional Debug Probe console input |
| GP8 | LCD_DC | command/data selection |
| GP9 | LCD_CS | LCD active-low chip select |
| GP10 | LCD_CLK | SPI1 clock |
| GP11 | MOSI | SPI1 transmit |
| GP12 | MISO | SPI1 receive; initialized for the shared bus |
| GP13 | LCD_BL | backlight, driven high |
| GP15 | LCD_RST | LCD active-low reset |
| GP16 | TP_CS | XPT2046 touch deselected |
| GP22 | SD_CS | microSD deselected |

The 320x240 display is an ST7789VW panel using RGB565 and SPI mode 0. Touch,
microSD, wireless, USB, interrupts, heap allocation, and multicore support are
purposely outside this first assembly exercise.

## Image and source layout

- `mise.toml` declares Debian host dependencies with `bootstrap.packages` and
  contains every build, packaging, inspection, and flashing task. `mise run
  link` assembles and links the ELF in one compiler invocation; `mise run uf2`
  packages it, and `mise run clean` removes generated output.
- `src/picobin.S` is the RP2350 boot ROM metadata block. It marks the image as
  an executable for the RP2350 RISC-V core and supplies the reset entry and
  initial stack address.
- `src/rp2350-riscv.ld` maps picobin metadata, executable code, and constants
  into XIP flash at `0x10000000`, reserves RAM at `0x20000000`, and exports
  startup boundaries.
- `src/start.S` sets the stack, copies `.data`, clears `.bss`, invokes `main`,
  and safely waits if it ever returns. The current application has no mutable
  initialized data, but the startup is complete for future lessons.
- `src/rp2350.inc` names the directly accessed RP2350 GPIO, reset, clock,
  PLL, SIO, and SPI registers.
- `src/main.S` configures the 12 MHz crystal and 150 MHz system PLL, configures
  the display signals and SPI1 at 37.5 MHz, initializes the vendor-specific
  ST7789VW settings, then draws text using a 5x7 bitmap font.

The RP2350 boot ROM makes an initial XIP flash configuration before entering
the picobin-declared RISC-V reset handler. The application then owns the
clock-tree setup, using the board's 12 MHz crystal and PLL_SYS at 150 MHz.
