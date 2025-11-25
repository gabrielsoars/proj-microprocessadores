.include "consts.s"

.global ROTATE_FUNCTIONS
ROTATE_FUNCTIONS:
    addi sp, sp, -4
	stw ra, 4(sp)
    # r8 já contém o endereço de cmd_buffer
    # Verifica o segundo caractere (r8 + 1)
    ldb r9, 1(r8)
    addi r9, r9, -48
    
    beq r9, r0, START_ROTATION # Se '0' -> Comando 20
    
    movi r10, 1
    beq r9, r10, STOP_ROTATION # Se '1' -> Comando 21
    
    ldw ra, 4(sp)
	addi sp, sp, 4
    ret

START_ROTATION:
    addi sp, sp, -4
	stw ra, 4(sp)

	movia r14, rotation_active
	movia r13, 1 
	stw r13, 0(r14)
    
    # Resetar variáveis de controle
    movia r14, rotation_dir
    stw r0, 0(r14) # 0 = Direita
    
    movia r14, rotation_paused
    stw r0, 0(r14) # 0 = Não pausado
    
    movia r14, rotation_offset
    stw r0, 0(r14)

    ldw ra, 4(sp)
	addi sp, sp, 4
    ret

STOP_ROTATION:
    addi sp, sp, -4
	stw ra, 4(sp)

    movia r14, rotation_active
    stw r0, 0(r14)
    
    # Limpar 8 displays
    movi r9, 0
    
    # Limpa HEX0-HEX3
    movia r8, SEVEN_SEG_LOW
    stbio r9, 0(r8)
    stbio r9, 1(r8)
    stbio r9, 2(r8)
    stbio r9, 3(r8)

    # Limpa HEX4-HEX7
    movia r8, SEVEN_SEG_HIGH
    stbio r9, 0(r8)
    stbio r9, 1(r8)
    stbio r9, 2(r8)
    stbio r9, 3(r8)
    
    ldw ra, 4(sp)
	addi sp, sp, 4
    ret
