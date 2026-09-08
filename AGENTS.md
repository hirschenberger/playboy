# AGENTS.md

## Project Purpose and Scope

This repository contains SDK-free bare-metal firmware for the RP2350/Pico 2 W
and the Waveshare Pico-ResTouch-LCD-2.8 (ST7789VW). The `.S` sources use GNU
assembler syntax with the C preprocessor, but Clang 19 assembles them and LLD
19 links them. There is intentionally no Pico SDK, C/C++, CMake, operating
system, or target runtime. Do not add new architecture variants, especially
ARM; the firmware build remains RISC-V- and LLVM-19-only. `picotool`,
`gdb-multiarch`, and OpenOCD remain the separate tools for packaging, flashing,
and debugging.

Always run `git status --short` before making changes and preserve uncommitted
user changes. `build/` and `.tools/` are generated or local and are not
versioned.

## Architecture and Data Flow

1. `src/picobin.S` is the first flash block at `0x10000000`. The RP2350 Boot
   ROM reads `IMAGE_TYPE=0x1101`, `_reset_handler`, and `__stack_top`.
2. `src/start.S` initializes the stack, copies `.data` from flash to RAM,
   clears `.bss`, and calls `main`. Only a return from `main` is guaranteed to
   end in a `wfi` loop. `_trap_handler` also exists, but the current code does
   not install it through `mtvec`; the firmware therefore does not define the
   actual trap destination.
3. `lcd_init` in `src/lcd.S` initializes the clock tree, UART0, LCD GPIO,
   SPI1, and the ST7789VW in that order.
4. `main` in `src/main.S` writes the UART boot message, clears the screen, and
   draws bars and rainbow text in an infinite loop.
5. Drawing flow: `draw_rainbow_string` -> `draw_rainbow_char` -> `fill_rect`
   -> `set_window` -> `write_color`. One color-table position applies to each
   glyph column; `draw_rainbow_char` returns the next color pointer in `a0`.
6. UART flow: NUL-terminated string in `a0` -> `uart_write_string` ->
   `uart_write_byte` -> UART0 TX on GP0.

## Files and Responsibilities

- `mise.toml`: the only build/flash/debug orchestration; LLVM 19 is pinned.
  Headers (`src/**/*.h`) intentionally count as build inputs. The link command
  compiles only `src/*.S`, however, so assembly placed in subdirectories would
  not be linked despite recursive source tracking.
- `src/rp2350-riscv.ld`: flash/RAM layout, picobin placement, `.data`/`.bss`
  boundaries, and the 4 KiB stack.
- `src/picobin.S`: Boot ROM metadata. Do not change its format, markers,
  `0x1101`, entry point, or stack address without a verified RP2350 boot
  requirement.
- `src/start.S`: minimal runtime and a trap endpoint that is not currently
  installed explicitly.
- `src/rp2350.h`: central register addresses, bits, pins, and clock divisors.
  Verify values against RP2350 documentation; some RP2040 bits differ.
- `src/lcd.S`: 12 MHz XOSC/PLL_SYS setup for 150 MHz, GPIO/SPI1, and the
  vendor-specific ST7789VW initialization sequence.
- `src/main.S`: frame loop, rectangle/text renderers, font, and RGB565
  gradient.
- `src/uart.S`: UART0 at 115200 8-N-1 on GP0/GP1 and blocking output.
- `.asm-lsp.toml`: RISC-V flags for `asm-lsp`. It names unversioned `clang`,
  not `clang-19`, so editor diagnostics can differ from the actual build.
- `README.md`: usage and hardware wiring. Keep it synchronized with workflow,
  pin, and clock changes. Its references to `rp2350.inc` are stale; the actual
  file is `src/rp2350.h`. Clock, GPIO, SPI, and panel initialization also live
  in `src/lcd.S` now, not `src/main.S`.

## Hardware and Timing Assumptions

- Display: ST7789VW, 320x240, RGB565, SPI mode 0.
- Pins: GP8 D/C, GP9 CS, GP10 SCK, GP11 MOSI, GP12 MISO, GP13 backlight,
  GP15 reset, GP16 touch CS, GP22 SD CS.
- UART: GP0 TX -> Debug Probe UART RX; both devices require a common ground.
  GP1 has its pad and UART pinmux configured, but `UART_CR` enables only the
  UART and TX, not RX; no input routine exists either.
- Clock tree: 12 MHz XOSC, 1.5 GHz PLL_SYS VCO, 150 MHz SYS/PERI. The code
  does not set the separate `CLK_SYS` divider and sets the AUXSRC fields to
  encoding 0 only implicitly by overwriting the complete CTRL registers with
  `0x1` and `0x800`. It therefore assumes encoding 0 means PLL_SYS for SYS-AUX
  and CLK_SYS for PERI, and that the existing SYS divider is 1.
- SPI1: CPSR=4, producing 37.5 MHz. Experiments at 60/75 MHz were unreliable
  on the available hardware; do not increase this without an explicit request
  and hardware testing.
- UART divisors 81/24 require `CLK_PERI=150 MHz`.
- On RP2350, `RESETS_UART0_BIT` is bit 26 (`0x04000000`), not the
  corresponding RP2040 value.

## Assembly Conventions

- Target: `rv32imac_zicsr_zifencei_zba_zbb_zbs_zbkb`, ABI `ilp32`.
- Follow the RISC-V ABI: `a*`/`t*` are caller-saved and `s*` are callee-saved.
  Non-leaf functions save `ra`; `sp` remains 16-byte aligned at call
  boundaries. `main` is the current exception: it intentionally never
  returns, uses `s1`/`s2` as persistent state, and saves neither them nor `ra`.
  If `main` is ever made returning, convert it to ABI-compliant code.
- Where a stack frame is needed, reserve it manually immediately after the
  function label. Function-prefixed `.equ` offsets and explicit `sw`/`lw`
  operations follow. Leaf functions have no frame. Do not reintroduce stack
  macros.
- Existing comments document calling contracts, primarily for routines with
  arguments. Document non-obvious new arguments and return values in the same
  way; do not silently alter existing contracts.
- Numeric local labels (`0:`, `1:`, and so on) are common and reused in each
  function. Check forward/backward (`f`/`b`) directions carefully before
  modifying control flow.
- RGB565 values are stored as halfwords and read with `lhu`. Here, `.align 1`
  means 2-byte alignment and is required for `rainbow_colors`.
- `write_color` assumes `set_window` has already enabled RAMWR and left CS
  low. It sends the high byte before the low byte and raises CS at the end.
- `set_window` uses inclusive end coordinates; `fill_rect` computes
  `x+width-1`, `y+height-1`, and sends `width*height` pixels.
- Font data covers ASCII `0x20` through `0x5a`. The renderers do not validate
  characters; lowercase letters or values outside this range read beyond the
  font table.
- Startup copies or clears `.data` and `.bss` one word at a time. The current
  sections are empty; future section sizes must be multiples of four bytes, or
  startup and linker script must be extended together to handle remaining
  bytes.

## Commands and Validation

```sh
mise bootstrap packages apply  # LLVM 19, picotool, GDB, and OpenOCD build dependencies
mise run build                 # ELF + UF2
mise run inspect               # ELF header, size, and UF2 metadata
mise run disassemble           # build/playboy.dis
mise run flash                 # prefer BOOTSEL, otherwise CMSIS-DAP/SWD
mise run debug                 # interactive GDB
mise run console               # /dev/ttyACM0, 115200 8-N-1
mise run clean
git diff --check
```

There are no automated tests or linter. For code changes, run at least
`mise run build` and `git diff --check`. For ABI, alignment, or control-flow
changes, also inspect the relevant functions with
`llvm-objdump-19 -d -S build/playboy.elf`. Display, boot, UART, and timing
behavior can only be validated conclusively on hardware.

## Flash and Debug Pitfalls

- Even for the BOOTSEL path, `mise run flash` depends on `setup-debugger` and
  initially builds OpenOCD locally. It then programs the UF2 and selects
  RISC-V if a BOOTSEL device is visible; otherwise it uses OpenOCD with
  `target/rp2350-riscv.cfg`.
- After an ARM boot, the Hazard3 cores are unavailable over SWD. Connect the
  Pico through its own USB data connection, enter BOOTSEL, and rerun
  `mise run flash`.
- `target remote` works for the flash workflow; `extended-remote` caused
  protocol errors with this OpenOCD build. The interactive `debug` task still
  uses `extended-remote` and is therefore potentially inconsistent.
- Aborted sessions can leave OpenOCD, port 3333, or the CMSIS-DAP interface
  occupied. Terminate only the specifically identified process.
- Hardware breakpoint resources are limited. Breakpoints on `.equ`
  directives, labels, comments, or blank lines have no executable source
  location.
- `build/openocd.log` is the first diagnostic source for SWD problems.

## Known Debt and Uncertainties

- Startup does not set `mtvec`. In addition, `_trap_handler` records neither
  the cause nor any registers. Traps therefore cannot currently be caught
  reliably at this symbol and may appear as silent hangs.
- All peripheral wait loops and initialization sequences lack timeouts.
- Text is drawn pixel by pixel through many `fill_rect`/window transactions
  and is intentionally slow; `write_color` optimizes only contiguous
  single-color areas.
- Persistent startup after a true power cycle has repeatedly been reported as
  problematic and is not conclusively known to be fixed in the current state.
  Change the picobin layout or `IMAGE_TYPE=0x1101` only with Boot ROM evidence
  and a subsequent true cold-start test.
- The serial device name `/dev/ttyACM0` is host-dependent and hard-coded in
  `mise.toml`.
- The comment for `draw_rainbow_string` in `src/main.S` is stale: each of the
  five glyph columns, not each character, consumes one color-table entry; the
  spacing column consumes none.
- `setup-debugger` clones the moving head of the `rpi-common` branch without a
  commit pin and does not update an existing checkout. OpenOCD builds are
  therefore not fully reproducible across fresh hosts.
- The linker script reserves 4 KiB immediately after `.bss`, but has neither a
  dedicated stack section nor an `ASSERT` against RAM overflow
