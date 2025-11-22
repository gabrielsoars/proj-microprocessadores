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
.equ STACK, 0x10000
.equ SEVEN_SEG_LOW,  0x10000020      # Displays HEX3 até HEX0
.equ SEVEN_SEG_HIGH, 0x10000030      # Displays HEX7 até HEX4
.equ SWITCHES_BASE, 0x10000040       # Chaves (SW)
.equ LEDS, 0x10000000
.equ TEMPORIZADOR, 0x10002000
.equ KEYS_BASE, 0x10000050           # Pushbuttons (KEY3-KEY0)

.org 0x20
	addi sp, sp, -4
	stw ra, (sp)

	rdctl et, ipending /* Check if external interrupt occurred */
	beq et, r0, OTHER_EXCEPTIONS /* If zero, check exceptions */
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
    movi r9, 0
	stwio r9, 0(r8) # Escreve 0 no status para limpar TO

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
    movi r12, 8           # Limite i < 8 (AGORA SÃO 8 DISPLAYS)
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

	addi r14, r0, 1
	bne r15, r14, LED_RETURN

	# operações para apagar o led digitado
	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14
	xor r18, r17, r11
	and r18, r18, r17

	stwio r18, (r12)

LED_RETURN:
	ret

ACENDER_LEDS:
	addi r13, r0, 1
	addi r14, r11, -1
	sll r11, r13, r14
	or r11, r11, r17
	stwio r11, (r12)
	
	ret

TRIANG_FUNCTION:
	movia r14, rotation_active
	stw r0, 0(r14) # CORREÇÃO: stw (word)

	# carrega o segundo termo digitado da memória
	ldb r15, 1(r8) # mudar para acessar como índice
	addi r15, r15, -48 # transforma termo digitado na memória em um inteiro

	bne r15, r0, TRIANG_RETURN # se não for 0 (comando: 10), vai para o fim da rotina

	addi sp, sp, -4

	stw ra, 4(sp)
	
    call _read_switches             # Lê chaves -> r2
    call _calc_triangular           # Calcula T(N) -> r4
    call _display_decimal           # Exibe nos displays

	ldw ra, 4(sp)
	addi sp, sp, 4
TRIANG_RETURN:
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

    movia r8, SEVEN_SEG_LOW
    movi r14, 0x0  # Código para display apagado
    movi r6, 10 # Divisor
    mov r7, r0 # Offset do display
    movi r5, 6 # Máximo 6 dígitos

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

    # Logica simples de escrita: Base + Offset
    # Se offset > 3 precisa mudar de base. 
    # Para simplificar a função triangular existente, vamos assumir que cabe em 4 displays ou adaptar:
    movi r13, 4
    blt r7, r13, DISP_DEC_LOW
    
    movia r11, SEVEN_SEG_HIGH
    subi r13, r7, 4
    add r11, r11, r13
    br DISP_DEC_WRITE

DISP_DEC_LOW:
    add r11, r8, r7

DISP_DEC_WRITE:
    stbio r9, 0(r11)

    addi r7, r7, 1
    bne r4, r0, LOOP_CONVERT_DISPLAY

# Apaga displays não utilizados
LOOP_BLANK_DIGITS:
    bge r7, r5, END_DISPLAY
    
    movi r13, 4
    blt r7, r13, BLANK_LOW
    movia r11, SEVEN_SEG_HIGH
    subi r13, r7, 4
    add r11, r11, r13
    br BLANK_WRITE

BLANK_LOW:
    add r11, r8, r7
BLANK_WRITE:
    stbio r14, 0(r11)
    addi r7, r7, 1
    br LOOP_BLANK_DIGITS

END_DISPLAY:
	ldw ra, 4(sp)
	addi sp, sp, 4
    ret

ROTATE_FUNCTIONS:
    # r8 já contém o endereço de cmd_buffer
    # Verifica o segundo caractere (r8 + 1)
    ldb r9, 1(r8)
    addi r9, r9, -48
    
    beq r9, r0, START_ROTATION # Se '0' -> Comando 20
    
    movi r10, 1
    beq r9, r10, STOP_ROTATION # Se '1' -> Comando 21
    
    ret

START_ROTATION:
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

    ret

STOP_ROTATION:
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
    
    ret

ENABLE_INTERRUPTIONS:
    movia r8, TEMPORIZADOR
    movi r10, 0
    stwio r10, 4(r8) # Stop
    stwio r10, 0(r8) # Clear TO

    movia r11, 10000000 # 200ms
    andi r10, r11, 0xFFFF
	stwio r10, 8(r8)
	srli r10, r11, 16
	stwio r10, 12(r8)

	movia r10, 0b111 # Start | Cont | ITO
	stwio r10, 4(r8)

    movia r10, 0b1
	wrctl ienable, r10
	movi r10, 1
	wrctl status, r10
	ret

.data
rotation_active:
	.word 0

.align 2
rotation_dir:    .word 0  # 0 = Dir, 1 = Esq
rotation_paused: .word 0  # 0 = Run, 1 = Pause
rotation_offset: .word 0  # Índice inicial da janela
prev_keys:       .word 0xFF # Estado anterior das chaves

display_pattern:
    .byte 0x00, 0x7D, 0x5B, 0x3F, 0x5B, 0x00, 0x06, 0x3F

msg_prompt:
    .string  "Entre com o comando: "

cmd_buffer:
    .skip   8      # espaço para 4 chars + ENTER

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