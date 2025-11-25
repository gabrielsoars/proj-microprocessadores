.global SWITCH_FUNCTIONS
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
