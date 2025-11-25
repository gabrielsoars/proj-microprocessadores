.global SWITCH_FUNCTIONS
SWITCH_FUNCTIONS:
	addi sp, sp, -4 # inicia 4 bytes no frame
	stw ra, 4(sp)

	movia r8, cmd_buffer
	movi r10, 1 # uso no verificação do prefixo do comando
	movi r11, 2 # uso no verificação do prefixo do comando
	ldb r9, 0(r8) # puxa o primeiro caractere do buffer

	addi r9, r9, -48 # transforma o caractere em inteiro
	beq r9, r0, LEDS_CALL # chama a rotina específica para acender/apagar leds

	beq r9, r10, TRIANG_CALL # chama a rotina específica para cálculo e apresentação do número triangular

	beq r9, r11, ROTATE_CALL # chama a rotina específica para a rotação

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
