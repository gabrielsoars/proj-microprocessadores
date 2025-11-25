/*
 * PSEUDOCODIGO
 *
 * while(true) {
 * 	print "Entre com o comando:"
 * 
 * 	com = getCommand() // UART (Polling)
 *
 * 	switch(com)
 * 		case '0': LED()
 * 		case '1': Triang()
 * 		case '2': Rotacao()
 * }
 *
 *
 * getCommand() {
 * 		lerValidUARTBit()
 *		lerBitsUARTData()
 *		verificarUARTWriteSpace()
 *		escreverBitNoTerminal()
 *		
 *		salvarBitNoBuffer()
 * 		indiceBuffer++
 *		
 *		if (bit == ENTER) {
 *			switchFunctions()
 *		}
 * }
 *
 * r16 -> UART address
 * r17 -> string
 * r18 -> bit de controle
 * 
 */

 .include "consts.s"

 .global MAIN_LOOP

.org 0x20
	addi sp, sp, -4
	stw ra, (sp)

	rdctl et, ipending # Check if external interrupt occurred 
	beq et, r0, OTHER_EXCEPTIONS  /* If zero, check exceptions */
	subi ea, ea, 4 /* Hardware interrupt, decrement ea to execute the interrupted */

	/* instruction upon return to main program */

	andi r13, et, 1 /* Check if irq0 asserted */
	beq r13, r0, OTHER_INTERRUPTS /* If not, check other external interrupts */
	call EXT_IRQ0

OTHER_INTERRUPTS:
	br FIM_RTI

OTHER_EXCEPTIONS:
	br FIM_RTI

FIM_RTI:
	ldw ra, (sp)
	addi sp, sp, 4
	eret

EXT_IRQ0:
    # Salva contexto
    addi sp, sp, -40
    stw r8, 0(sp)
    stw r9, 4(sp)
    stw r10, 8(sp)
    stw r11, 12(sp)
    stw r12, 16(sp)
    stw r13, 20(sp)
    stw r14, 24(sp)
    stw r15, 28(sp)
    stw r16, 32(sp)
    stw r17, 36(sp)

	# limpar o bit TO do Status Register (limpa o ipending)
	movia r8, TEMPORIZADOR
	stwio r0, 0(r8) # Escreve 0 no status para limpar TO

    # Verifica se a rotação está ativa
	movia r12, rotation_active
	ldw r9, 0(r12)
	beq r9, r0, IRQ_EXIT

    # --- Lógica dos Botões ---
    movia r8, KEYS_BASE
    ldwio r9, 0(r8)       # Lê chaves atuais (KEY3..0)
    
    # Detecta Borda (Falling Edge/Press): Edge = Prev & (~Curr)
    movia r13, prev_keys
    ldw r10, 0(r13)       # r10 = Estado anterior
    stw r9, 0(r13)        # Atualiza estado anterior com o atual
    
    nor r14, r9, r0       # Inverte (active low -> active high)
    and r11, r10, r14     # Detecta borda de descida

    # KEY1: Inverter Direção
    andi r15, r11, 0b10
    beq r15, r0, CHECK_KEY2
    
    movia r14, rotation_dir
    ldw r15, 0(r14)
    xori r15, r15, 1      # Toggle 0 <-> 1
    stw r15, 0(r14)

CHECK_KEY2:
    # Verifica KEY2 (bit 2) -> Pausar/Resumir
    andi r15, r11, 0b100
    beq r15, r0, CHECK_ROTATION

    movia r14, rotation_paused
    ldw r15, 0(r14)
    xori r15, r15, 1
    stw r15, 0(r14)

CHECK_ROTATION:
    movia r14, rotation_paused
    ldw r15, 0(r14)
    bne r15, r0, UPDATE_DISPLAY

    # --- Atualiza Offset ---
    movia r14, rotation_offset
    ldw r10, 0(r14)       # Offset atual
    
    movia r13, rotation_dir
    ldw r15, 0(r13)       # Direção (0=Direita, 1=Esquerda)
    bne r15, r0, DIR_LEFT

DIR_RIGHT:
    # Para rotacionar texto p/ direita, a janela (offset) move-se p/ esquerda (decrementa)
    subi r10, r10, 1
    bge r10, r0, SAVE_OFFSET
    movi r10, 8
    br SAVE_OFFSET

DIR_LEFT:
    addi r10, r10, 1
    movi r15, 8
    blt r10, r15, SAVE_OFFSET
    movi r10, 0

SAVE_OFFSET:
    stw r10, 0(r14)

UPDATE_DISPLAY:
    # --- Redesenha os 8 displays ---
    # r10 = offset inicial do buffer
    # r11 = contador do loop (0 a 7)
    
    movia r9, display_pattern
    movia r14, rotation_offset
    ldw r10, 0(r14)
    
    movi r11, 0           # i = 0
    movi r12, 8           # Limite i < 8
    movi r13, 8          # Tamanho do buffer circular

LOOP_DISP:
    # 1. Buscar o caractere no buffer
    add r15, r10, r11     # index_buffer = offset + i
    
    # Modulo manual: se index >= 12, index -= 12
    blt r15, r13, FETCH_CHAR
    sub r15, r15, r13

FETCH_CHAR:
    add r16, r9, r15      # Endereço do byte no array
    ldb r14, 0(r16)       # r14 = Código 7-seg
    
    # 2. Decidir em qual endereço de hardware escrever
    # Se i (r11) < 4 -> usa SEVEN_SEG_LOW
    # Se i (r11) >= 4 -> usa SEVEN_SEG_HIGH
    
    movi r17, 4
    blt r11, r17, WRITE_LOW

WRITE_HIGH:
    movia r8, SEVEN_SEG_HIGH
    sub r17, r11, r17     # offset_hw = i - 4
    add r16, r8, r17      # Endereço final = BaseHigh + (i-4)
    stbio r14, 0(r16)
    br NEXT_ITER

WRITE_LOW:
    movia r8, SEVEN_SEG_LOW
    add r16, r8, r11      # Endereço final = BaseLow + i
    stbio r14, 0(r16)

NEXT_ITER:
    addi r11, r11, 1
    blt r11, r12, LOOP_DISP

IRQ_EXIT:
    ldw r8, 0(sp)
    ldw r9, 4(sp)
    ldw r10, 8(sp)
    ldw r11, 12(sp)
    ldw r12, 16(sp)
    ldw r13, 20(sp)
    ldw r14, 24(sp)
    ldw r15, 28(sp)
    ldw r16, 32(sp)
    ldw r17, 36(sp)
    addi sp, sp, 40
	br FIM_RTI

.global _start
_start:
	movia sp, STACK # Inicializa stack pointer
    
	call ENABLE_INTERRUPTIONS

	movia r16, UART

	MAIN_LOOP:
		movia r23, cmd_buffer

		# print "Entre com o comando: "
		movia r17, msg_prompt
		call _print_string

		# getCommand()
		call get_command  # lê o que foi digitado no terminal e salva no buffer até encontrar um ENTER
		
		call SWITCH_FUNCTIONS # lê o que foi salvo no buffer e redireciona para as rotinas especializadas

		br MAIN_LOOP

.data
.global rotation_active
rotation_active:
	.word 0

.global rotation_dir
rotation_dir:    .word 0  # 0 = Dir, 1 = Esq
.global rotation_paused
rotation_paused: .word 0  # 0 = Run, 1 = Pause
.global rotation_offset
rotation_offset: .word 0  # Índice inicial da janela
prev_keys:       .word 0xFF # Estado anterior das chaves

.global msg_prompt
msg_prompt:
    .string  "Entre com o comando: "

.global cmd_buffer
cmd_buffer:
    .skip   8      # espaço para 4 chars + ENTER

.global display_pattern
display_pattern:
    .byte 0x00, 0x7D, 0x5B, 0x3F, 0x5B, 0x00, 0x06, 0x3F
