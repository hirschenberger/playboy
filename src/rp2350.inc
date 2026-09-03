.equ IO_BANK0_BASE,       0x40028000
.equ PADS_BANK0_BASE,     0x40038000
.equ RESETS_BASE,         0x40020000
.equ SPI1_BASE,           0x40088000
.equ SIO_BASE,            0xd0000000

.equ RESETS_RESET,        0x00
.equ RESETS_RESET_DONE,   0x08
.equ RESETS_SPI1_BIT,     0x00080000

.equ GPIO_CTRL_BASE,      0x04
.equ GPIO_CTRL_STRIDE,    0x08
.equ GPIO_FUNC_SPI1,      0x01
.equ GPIO_FUNC_SIO,       0x05
.equ PADS_GPIO_BASE,      0x04
.equ PADS_GPIO_STRIDE,    0x04
.equ PADS_OUTPUT_4MA,     0x16

.equ SIO_GPIO_OUT_SET,    0x18
.equ SIO_GPIO_OUT_CLR,    0x20
.equ SIO_GPIO_OE_SET,     0x38

.equ SPI_CR0,             0x00
.equ SPI_CR1,             0x04
.equ SPI_DR,              0x08
.equ SPI_SR,              0x0c
.equ SPI_CPSR,            0x10
.equ SPI_CR0_8BIT_MODE0,  0x07
.equ SPI_CR1_ENABLE,      0x02
.equ SPI_SR_TNF,          0x02
.equ SPI_SR_RNE,          0x04
.equ SPI_SR_BSY,          0x10

.equ LCD_DC_PIN,          8
.equ LCD_CS_PIN,          9
.equ LCD_SCK_PIN,         10
.equ LCD_MOSI_PIN,        11
.equ LCD_BL_PIN,          13
.equ LCD_RST_PIN,         15
.equ TOUCH_CS_PIN,        16
.equ SD_CS_PIN,           22

.equ LCD_DC_MASK,         (1 << LCD_DC_PIN)
.equ LCD_CS_MASK,         (1 << LCD_CS_PIN)
.equ LCD_BL_MASK,         (1 << LCD_BL_PIN)
.equ LCD_RST_MASK,        (1 << LCD_RST_PIN)
.equ TOUCH_CS_MASK,       (1 << TOUCH_CS_PIN)
.equ SD_CS_MASK,          (1 << SD_CS_PIN)
.equ LCD_GPIO_MASK,       (LCD_DC_MASK | LCD_CS_MASK | LCD_BL_MASK | LCD_RST_MASK | TOUCH_CS_MASK | SD_CS_MASK)

.equ ST_SWRESET,          0x01
.equ ST_SLPOUT,           0x11
.equ ST_COLMOD,           0x3a
.equ ST_MADCTL,           0x36
.equ ST_INVON,            0x21
.equ ST_DISPON,           0x29
.equ ST_CASET,            0x2a
.equ ST_RASET,            0x2b
.equ ST_RAMWR,            0x2c

.equ SCREEN_WIDTH,        320
.equ SCREEN_HEIGHT,       240
