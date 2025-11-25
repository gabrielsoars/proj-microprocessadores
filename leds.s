.include "consts.s"

.global LED_FUNCTIONS
LED_FUNCTIONS:
	addi sp, sp, -4 # inicia 4 bytes no frame
	stw ra, 4(sp)

	ldb r15, 1(r8) # lê o segundo caractere do buffer
	addi r15, r15, -48 # transforma o caractere em inteiro
	ldb r9, 2(r8) # lê o terceiro caractere no buffer
	addi r9, r9, -48 # transforma o caractere em inteiro
	
	mov r10, r9 # copia r9 pra r10
	slli r9, r9, 1 # multiplica r9 por 2
	slli r10, r10, 3 # multiplica r10 por 8
	add r9, r9, r10 # soma r9 e r10 (multiplicação por 10 do número digitado)

	ldb r10, 3(r8) # lê o quarto caractere no buffer
	addi r10, r10, -48 # transforma o caractere em inteiro

	add r11, r9, r10 # soma as unidades com a dezena

	movia r12, LEDS
	ldwio r17, (r12) # acessa o estado atual dos leds

	beq r15, r0, ACENDER_LEDS # se o segundo caracter no buffer for 0, vai pra rotina de acender led

	# rotina para apagar leds
	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14 # forma uma máscara com um bit 1 no índice escolhido
	xor r18, r17, r11 # compara usando um xor o estado atual dos leds com a máscara implementada
	and r18, r18, r17

	stwio r18, (r12)
	
	ldw ra, 4(sp)
	addi sp, sp, 4
	ret

ACENDER_LEDS:
	addi sp, sp, -4 # inicia 4 bytes no frame

	stw ra, 4(sp)

	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14 # forma uma máscara com um bit 1 no índice escolhido
	or r11, r11, r17 # usa um or pra restaurar o estado atual dos leds e acender o led escolhido
	stwio r11, (r12)
	
	ldw ra, 4(sp)
	addi sp, sp, 4
	ret
