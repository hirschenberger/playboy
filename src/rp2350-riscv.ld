ENTRY(_reset_handler)

MEMORY
{
    FLASH (rx)  : ORIGIN = 0x10000000, LENGTH = 4M
    RAM   (rwx) : ORIGIN = 0x20000000, LENGTH = 520K
}

SECTIONS
{
    .picobin : ALIGN(4)
    {
        KEEP(*(.picobin))
    } > FLASH

    .text : ALIGN(4)
    {
        KEEP(*(.reset))
        *(.text .text.*)
    } > FLASH

    .rodata : ALIGN(4)
    {
        *(.rodata .rodata.*)
    } > FLASH

    .data : ALIGN(4)
    {
        __data_start = .;
        *(.data .data.*)
        __data_end = .;
    } > RAM AT > FLASH
    __data_load_start = LOADADDR(.data);

    .bss (NOLOAD) : ALIGN(4)
    {
        __bss_start = .;
        *(.bss .bss.* COMMON)
        __bss_end = .;
    } > RAM

    . = ALIGN(16);
    __stack_bottom = .;
    . += 4096;
    __stack_top = .;

    . = ALIGN(16);
    __stack_bottom_core1 = .;
    . += 4096;
    __stack_top_core1 = .;

    /DISCARD/ :
    {
        *(.comment .note .eh_frame)
    }
}
