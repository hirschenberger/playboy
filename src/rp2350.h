.equ IO_BANK0_BASE,       0x40028000
.equ PADS_BANK0_BASE,     0x40038000
.equ RESETS_BASE,         0x40020000
.equ CLOCKS_BASE,         0x40010000
.equ XOSC_BASE,           0x40048000
.equ PLL_SYS_BASE,        0x40050000
.equ UART0_BASE,          0x40070000
.equ SPI1_BASE,           0x40088000
.equ TIMER0_BASE,         0x400b0000
.equ TICKS_BASE,          0x40108000
.equ SIO_BASE,            0xd0000000

.equ RESETS_RESET,        0x00
.equ RESETS_RESET_DONE,   0x08
.equ RESETS_SPI1_BIT,     0x00080000
.equ RESETS_TIMER0_BIT,   0x00800000
.equ RESETS_UART0_BIT,    0x04000000
.equ RESETS_PLL_SYS_BIT,  0x00004000
.equ CLOCKS_CLK_REF_CTRL, 0x30
.equ CLOCKS_CLK_REF_SELECTED, 0x38
.equ CLOCKS_CLK_SYS_CTRL, 0x3c
.equ CLOCKS_CLK_SYS_SELECTED, 0x44
.equ CLOCKS_CLK_PERI_CTRL, 0x48
.equ CLOCKS_CLK_PERI_ENABLE, 0x00000800
.equ CLOCKS_CLK_PERI_ENABLED, 0x10000000
.equ CLOCKS_CLK_REF_XOSC, 0x02
.equ CLOCKS_CLK_REF_XOSC_SELECTED, 0x04
.equ CLOCKS_CLK_SYS_AUX,  0x01
.equ CLOCKS_CLK_SYS_AUX_SELECTED, 0x02
.equ XOSC_CTRL,           0x00
.equ XOSC_STATUS,         0x04
.equ XOSC_STARTUP,        0x0c
.equ XOSC_CTRL_ENABLE_12MHZ, 0x00fabaa0
.equ XOSC_STATUS_STABLE,  0x80000000
.equ PLL_CS,              0x00
.equ PLL_PWR,             0x04
.equ PLL_FBDIV_INT,       0x08
.equ PLL_PRIM,            0x0c
.equ PLL_CS_LOCK,         0x80000000
.equ PLL_PWR_PD,          0x00000001
.equ PLL_PWR_POSTDIVPD,   0x00000008
.equ PLL_PWR_VCOPD,       0x00000020
.equ PLL_SYS_REFDIV,      1
.equ PLL_SYS_FBDIV,       125
.equ PLL_SYS_POSTDIVS,    0x00052000

.equ GPIO_CTRL_BASE,      0x04
.equ GPIO_CTRL_STRIDE,    0x08
.equ GPIO_FUNC_SPI1,      0x01
.equ GPIO_FUNC_UART,      0x02
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
.equ SPI_CPSR_37_5MHZ,    4
.equ SPI_CR0_8BIT_MODE0,  0x07
.equ SPI_CR1_ENABLE,      0x02
.equ SPI_SR_TNF,          0x02
.equ SPI_SR_RNE,          0x04
.equ SPI_SR_BSY,          0x10

.equ TIMER_TIMEHR,        0x08
.equ TIMER_TIMELR,        0x0c
.equ TIMER_SOURCE,        0x38
.equ TIMER_SOURCE_TICK,   0x00

.equ TICKS_TIMER0_CTRL,   0x18
.equ TICKS_TIMER0_CYCLES, 0x1c
.equ TICKS_TIMER0_ENABLE, 0x01
.equ TICKS_TIMER0_1US,    12

.equ UART_DR,             0x00
.equ UART_FR,             0x18
.equ UART_IBRD,           0x24
.equ UART_FBRD,           0x28
.equ UART_LCR_H,          0x2c
.equ UART_CR,             0x30
.equ UART_FR_TXFF,        0x20
.equ UART_LCR_H_WLEN_8,   0x60
.equ UART_CR_ENABLE_TX,   0x101
.equ UART0_IBRD_115200,   81
.equ UART0_FBRD_115200,   24

.equ UART_TX_PIN,         0
.equ UART_RX_PIN,         1
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
