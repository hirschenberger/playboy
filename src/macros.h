.macro INIT_STACK size
    addi sp, sp, -\size
    .set __STACK_SIZE, \size
.endm

.macro PUSH_STACK name offset register
    .set \name, \offset
    sw \register, \name(sp)
.endm

.macro EXIT_STACK
    lw ra, RA(sp)
    addi sp, sp, __STACK_SIZE
.endm
