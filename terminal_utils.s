.global _print_string
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

.global get_command
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

		movia r13, 0x08
		beq r10, r13, NAO_SALVA
		stb r10, 0(r23)             # salva no buffer
		addi    r23, r23, 1

	NAO_SALVA:
		movia r13, 0xA # Carrega o valor ENTER para r13
		bne r10, r13, LOOP_DATA # Verifica se o caractere lido é ENTER

    ret
