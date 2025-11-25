.include "consts.s"

.global ENABLE_INTERRUPTIONS
ENABLE_INTERRUPTIONS:
    movia r8, TEMPORIZADOR
    stwio r0, 4(r8) # Stop
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
