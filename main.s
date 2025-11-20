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

.equ UART, 0x10001000
.equ	STACK, 0x10000
.equ SEVEN_SEG_BASE, 0x10000020      # Displays 7 Segmentos (HEX)
.equ SWITCHES_BASE, 0x10000040       # Chaves (SW)
.equ LEDS, 0x10000000
.equ APAGAR_MASK, 0x11111110

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

ROTATE_FUNCTIONS:
    ret

.org 0x500
msg_prompt:
    .string  "Entre com o comando: "

cmd_buffer:
    .skip   8      # espaço para 4 chars + ENTER

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