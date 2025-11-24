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

.global _start
_start:
	movia sp, 0x7FFFFC # Inicializa stack pointer	
	movia r16, UART


	MAIN_LOOP:		
		movia r23, cmd_buffer		

		# print "Entre com o comando: "
		movia r17, msg_prompt
		call _print_string

		# getCommand()
		call get_command  # lê o que foi digitado no terminal e salva no buffer até encontrar um ENTER
		
		call SWITCH_FUNCTIONS

		br      MAIN_LOOP

_print_string:

	ldb r18, 0(r17)
	beq r18, r0, END_PRINT_TEXT

	LOOP_PRINT:
		ldwio r19, 4(r16)
		andhi r19, r19, 0xFFFF
		beq r19, r0, LOOP_PRINT
		
		stwio r18, 0(r16)
		addi r17, r17, 1

		br _print_string

	END_PRINT_TEXT:
		ret

get_command:
	LOOP_DATA:
		ldwio r8, 0(r16) # Ler Data Register
		andi r10, r8, 0x8000
		beq r10, r0, LOOP_DATA

		# dado <- 8 bits inferiores de r
		andi r10, r8, 0x00FF

	LOOP_CONTROL:
		ldwio r15, 4(r16)
		andhi r15, r15, 0xFFFF
		beq r15, r0, LOOP_CONTROL

		stbio r10, 0(r16)

		stb r10, 0(r23)             # salva no buffer
		addi    r23, r23, 1

		movia r13, 0xA # Carrega o valor ENTER para r13
		bne r10, r13, LOOP_DATA # Verifica se o caractere lido é ENTER

    ret

SWITCH_FUNCTIONS:
	addi sp, sp, -4 # inicia 4 bytes no frame

	stw ra, 4(sp)

	movia r8, cmd_buffer
	movi r10, 1
	movi r11, 2
	ldb r9, 0(r8)

	addi r9, r9, -48
	beq r9, r0, LEDS_CALL

	beq r9, r10, TRIANG_CALL

	beq r9, r11, ROTATE_CALL

	ldw ra, 4(sp)
	addi sp, sp, 4

	ret

LEDS_CALL:
	call LED_FUNCTIONS
	br MAIN_LOOP

TRIANG_CALL:
	call TRIANG_FUNCTION
	br MAIN_LOOP

ROTATE_CALL:
	call ROTATE_FUNCTIONS
	br MAIN_LOOP

.data
rotation_active:
	.word 0

.align 2
.global rotation_dir
rotation_dir:    .word 0  # 0 = Dir, 1 = Esq
.global rotation_paused
rotation_paused: .word 0  # 0 = Run, 1 = Pause
.global rotation_offset
rotation_offset: .word 0  # Índice inicial da janela
prev_keys:       .word 0xFF # Estado anterior das chaves

msg_prompt:
    .string  "Entre com o comando: "

cmd_buffer:
    .skip   8      # espaço para 4 chars + ENTER
