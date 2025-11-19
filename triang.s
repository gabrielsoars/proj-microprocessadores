.equ SEVEN_SEG_BASE, 0x10000020      # Displays 7 Segmentos (HEX)
.equ SWITCHES_BASE, 0x10000040       # Chaves (SW)

.global TRIANG_FUNCTION
TRIANG_FUNCTION:
	addi sp, sp, -4

	stw ra, 4(sp)
	
    call _read_switches             # Lê chaves -> r2
    call _calc_triangular           # Calcula T(N) -> r4
    call _display_decimal           # Exibe nos displays

	ldw ra, 4(sp)
	addi sp, sp, 4
    ret


# --- Lê o valor das chaves (SW7-SW0) ---
# Retorna: r2 = valor 8 bits
_read_switches:
	addi sp, sp, -4

	stw ra, 4(sp)

    movia r8, SWITCHES_BASE
    ldwio r2, 0(r8)
    andi r2, r2, 0xFF               # Mantém apenas 8 bits

	ldw ra, 4(sp)
	addi sp, sp, 4
    ret


# --- Calcula número triangular: T(N) = N*(N+1)/2 ---
# Entrada: r2 = N
# Retorna: r4 = T(N)
_calc_triangular:
	addi sp, sp, -4

	stw ra, 4(sp)

    addi r3, r2, 1                  # r3 = N + 1
    mul  r4, r2, r3                 # r4 = N * (N + 1)
    srli r4, r4, 1                  # r4 = (N * (N + 1)) / 2
    
	ldw ra, 4(sp)
	addi sp, sp, 4
	ret


# --- Exibe número em decimal nos displays 7-seg ---
# Entrada: r4 = número a exibir
# Usa: r5, r6, r7, r8, r9, r10, r11, r14
_display_decimal:
	addi sp, sp, -4

	stw ra, 4(sp)

    movia r8, SEVEN_SEG_BASE
    movi r14, 0x0                  # Código para display apagado
    movi r6, 10                     # Divisor
    mov r7, r0                      # Offset do display
    movi r5, 6                      # Máximo 6 dígitos

    # Trata caso especial: número zero
    bne r4, r0, LOOP_CONVERT_DISPLAY
    movia r10, SEVEN_SEG_TABLE
    ldb r9, 0(r10)                  # Código para '0'
    stbio r9, 0(r8)                 # Escreve no HEX0
    addi r7, r7, 1
    br LOOP_BLANK_DIGITS

# Converte binário -> decimal via divisão sucessiva por 10
LOOP_CONVERT_DISPLAY:
    mov r9, r4
    div r4, r4, r6                  # Quociente
    mul r10, r4, r6
    sub r9, r9, r10                 # Resto = dígito decimal

    # Busca código 7-seg na tabela
    movia r10, SEVEN_SEG_TABLE
    add r10, r10, r9
    ldb r9, 0(r10)

    # Escreve no display correto
    add r11, r8, r7
    stbio r9, 0(r11)

    addi r7, r7, 1
    bne r4, r0, LOOP_CONVERT_DISPLAY

# Apaga displays não utilizados
LOOP_BLANK_DIGITS:
    bge r7, r5, END_DISPLAY
    add r11, r8, r7
    stbio r14, 0(r11)
    addi r7, r7, 1
    br LOOP_BLANK_DIGITS

END_DISPLAY:
	ldw ra, 4(sp)
	addi sp, sp, 4
    ret


.data
# Tabela de códigos 7-segmentos (cátodo comum - DE2)
SEVEN_SEG_TABLE:
    .byte 0x3F  # 0
    .byte 0x06  # 1
    .byte 0x5B  # 2
    .byte 0x4F  # 3
    .byte 0x66  # 4
    .byte 0x6D  # 5
    .byte 0x7D  # 6
    .byte 0x07  # 7
    .byte 0x7F  # 8
    .byte 0x6F  # 9
    .align 2