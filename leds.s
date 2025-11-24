.include "consts.s"

.global LED_FUNCTIONS
LED_FUNCTIONS:
	ldb r15, 1(r8) # mudar pra acessar como índice
	addi r15, r15, -48
	ldb r9, 2(r8) # mudar pra acessar como índice
	addi r9, r9, -48
	
	mov r10, r9 # copia r9 pra r10
	slli r9, r9, 1 # multiplica r9 por 2
	slli r10, r10, 3 # multiplica r10 por 8
	add r9, r9, r10 # soma r9 e r10 (multiplicação por 10 do número digitado)

	ldb r10, 3(r8) # mudar pra acessar como índice
	addi r10, r10, -48

	add r11, r9, r10

	# se o valor digitado (r11) é maior que 18, sai da função

	movia r12, LEDS
	ldwio r17, (r12)

	beq r15, r0, ACENDER_LEDS

	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14
	xor r18, r17, r11
	and r18, r18, r17

	stwio r18, (r12)
	
	ret

ACENDER_LEDS:
	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14
	or r11, r11, r17
	stwio r11, (r12)
	
	ret