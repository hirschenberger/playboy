# Pico 2 W RISC-V LCD Hello World

This is a first bare-metal RISC-V assembly project for a Raspberry Pi Pico 2 W
and Waveshare Pico-ResTouch-LCD-2.8. It draws `HELLO, WORLD!` on the 320x240
panel using the RP2350's Hazard3 RISC-V core.

## Hardware

Mount the Pico 2 W directly on the LCD board with the Pico USB connector facing
the same direction as the LCD board's microSD slot. The board fixes these pins:

| GPIO | Signal | Role |
|---:|---|---|
| GP8 | LCD_DC | command/data select |
| GP9 | LCD_CS | active-low LCD select |
| GP10 | LCD_CLK | SPI1 SCK |
| GP11 | MOSI | SPI1 transmit |
| GP12 | MISO | unused by this write-only display |
| GP13 | LCD_BL | backlight |
| GP15 | LCD_RST | hardware reset |
| GP16 | TP_CS | held high; touch is deferred |
| GP17 | TP_IRQ | unused; touch is deferred |

The display controller is **ST7789VW** and uses mode-0 SPI with RGB565 pixel
data. XPT2046 touch support is intentionally not part of this display-only
lesson.

## Setup and build

Run the dependency bootstrap once. It installs the RISC-V GCC/binutils plus
the matching Picolibc and C++ runtime packages,
`picotool`, CMake/Ninja prerequisites, and clones Pico SDK 2.3.0 into
`.deps/pico-sdk`:

```sh
./scripts/setup-deps.sh
cmake --preset pico2-riscv
cmake --build --preset pico2-riscv
```

The firmware is `build/pico2-riscv/pico2_lcd_hello.uf2`. Hold **BOOTSEL** while
connecting the Pico USB cable, then copy that UF2 onto the mounted `RPI-RP2`
drive. Alternatively, when `picotool` can find the board:

```sh
picotool load -f build/pico2-riscv/pico2_lcd_hello.uf2
picotool reboot
```

`PICO_SDK_PATH` can point at an existing Pico SDK installation. The CMake preset
selects `PICO_PLATFORM=rp2350-riscv` and `PICO_BOARD=pico2_w`; do not use the
installed ARM compiler for this project. Debian's multilib package is prefixed
`riscv64-unknown-elf`, but the preset explicitly directs it to produce the
RP2350's 32-bit RISC-V code.

Debian packages Picolibc separately from its RISC-V GCC. The project passes
its `/usr/lib/picolibc/riscv64-unknown-elf/picolibc.specs` compiler and linker
specs so the 32-bit headers and runtime are located correctly.

## Assembly tour

`src/main.S` is the whole application:

1. `lcd_gpio_init` removes pad isolation, assigns GP10/11 to SPI1, and makes
   the control pins SIO outputs.
2. `spi1_init` releases SPI1 reset and selects 8-bit, mode-0 SPI at the
   vendor reference 3.90625 MHz (125 MHz / 32).
3. `st7789_init` applies Waveshare's ST7789VW power, gamma, and RGB565
   initialization sequence before selecting landscape output.
4. `set_window` and `write_color` demonstrate command/data transactions and
   address-window pixel streaming.
5. `draw_string` and `draw_char` walk a 5x7 ASCII bitmap font and construct
   scaled pixels using RGB565 rectangles.

`src/rp2350.inc` names the RP2350 peripheral registers and LCD commands used by
the lesson. It is deliberately small enough to compare with the Pico SDK's
generated RP2350 register headers.

## Troubleshooting

- The current diagnostic image lights the GP13 backlight for two seconds,
  turns it off for one quarter-second, then initializes the controller. If the
  panel never lights during that first two seconds, stop debugging SPI: inspect
  USB power/cable, the direct-header mounting direction, and the GP13/backlight
  hardware path first.
- A lit but blank panel usually means the Pico is mounted backwards, `LCD_RST`
  is not released, or the wrong display controller initialization was used.
- Garbled pixels commonly indicate an SPI mode/order error; this board needs
  CPOL=0, CPHA=0 and MSB-first transfers.
- Wrong colors are normally RGB565 byte ordering or the ST7789 BGR bit; this
  example selects BGR with `MADCTL=0x60`.
- If CMake cannot find a RISC-V compiler, rerun `setup-deps.sh` or ensure
  `riscv64-unknown-elf-gcc` is on `PATH`. The Pico SDK accepts that multilib
  toolchain for its 32-bit RISC-V target.
- Touch shares SPI1 but is deliberately deselected. Add XPT2046 commands and
  calibration only after this greeting works.
