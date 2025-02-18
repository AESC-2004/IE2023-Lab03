;
; Lab03.asm
;
; Created: 17/02/2025 16:54:59
; Author : ang50
;


.include "M328PDEF.inc"

;Establecer dirección en DATA mem. para utilizar el X pointer
.DSEG
DISP7SEG_RAM:
	.BYTE 16	;rESERVAR 16 BYTES en RAM para la tabla

;Program mem.
.CSEG
.org 0x0000
	RJMP SETUP

;Guardamos un salto a la sub-rutina "PIN_CHANGE" en el vector de interrupción necesario
.org PCI1addr ;Pin Change Interrupt 1 (PORTC)
	RJMP	PIN_CHANGE

;Guardamos un salto a la sub-rutina "TIMER_RESET_AND_DISPS_TOGGLE" en el vector de interrupción necesario
.org  OVF0addr
	RJMP TIMER_RESET_AND_DISPS_TOGGLE

;Establecer dirección en program mem. LUEGO de los vectores de interrupción de TIM0
.org 0x0022
DISP7SEG:	
	.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;Definición de registros importantes
.def	COUNTMILLIS		= R19
.def	COUNTDECS		= R18
.def	COUNTSECS		= R20
.def	COUNTSECStemp	= R21
.def	COUNTDECStemp	= R25
.def	COUNT			= R22
;.def	COUNTtemp		= R21
.def	PBUP_LASTVALUE	= R23
.def	PBDWN_LASTVALUE	= R24

SETUP:
	;Deshabilitar interrupciones globales en el SETUP
	CLI

	;Establecemos el ZPointer en la dirección de DISP7SEG
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)

	;Establecemos el XPointer en la dirección de DISP7SEG
	LDI		XL, LOW(DISP7SEG_RAM << 1)
	LDI		XH, HIGH(DISP7SEG_RAM << 1)
	;Almacenamos datos manualmente en RAM
	LDI		R16, 0x3F
	ST		X+, R16
	LDI		R16, 0x06
	ST		X+, R16
	LDI		R16, 0x5B
	ST		X+, R16
	LDI		R16, 0x4F
	ST		X+, R16
	LDI		R16, 0x66
	ST		X+, R16
	LDI		R16, 0x6D
	ST		X+, R16
	LDI		R16, 0x7D
	ST		X+, R16
	LDI		R16, 0x07
	ST		X+, R16
	LDI		R16, 0x7F
	ST		X+, R16
	LDI		R16, 0x67
	ST		X+, R16
	LDI		R16, 0x77
	ST		X+, R16
	LDI		R16, 0x7C
	ST		X+, R16
	LDI		R16, 0x39
	ST		X+, R16
	LDI		R16, 0x5E
	ST		X+, R16
	LDI		R16, 0x79
	ST		X+, R16
	LDI		R16, 0x71
	ST		X+, R16
	;Re-dirigimos el XPointer
	LDI		XL, LOW(DISP7SEG_RAM << 1)
	LDI		XH, HIGH(DISP7SEG_RAM << 1)
	
	;Configurar STACK
	LDI		R16, LOW(RAMEND)
	OUT		SPL, R16
	LDI		R16, HIGH(RAMEND)
	OUT		SPH, R16

	;Configurar Prescaler "Global" de 16 (DATASHEET P.45)	|	16MHz a 1MHz
	LDI		R16, (1 << CLKPCE)
	STS		CLKPR, R16
	LDI		R16, (1 << CLKPS2)
	STS		CLKPR, R16

	;Deshabilitar serial (Importante; se utilizará PD para el display)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	;Configurar I/O PORTS (DDRx, PORTx)
	;PORTD: COUNTSECS Out (PD0,1,2,3,4,5,6)		|	PORTD: 0XXXXXXX
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000
	OUT		PORTD, R16
	;PORTB: BIN Out (PB0,1,2,3)								|	PORTB: 0000XXXX
	LDI		R16, 0x0F
	OUT		DDRB, R16
	LDI		R16, 0x00
	OUT		PORTB, R16
	;PORTC: BIN In (PC0,1), DISPSMUXOUT (PC2,3)				|	PORTC: 0000XX11
	LDI		R16, 0b00001100
	OUT		DDRC, R16
	LDI		R16, 0b00000111 ;Comenzamos encendiendo DISPUNIS
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	LDI		COUNT, 0
	LDI		COUNTMILLIS, 0x00
	LDI		COUNTSECS, 0x00
	LDI		COUNTDECS, 0x00
	LDI		PBUP_LASTVALUE, 0b00000001
	LDI		PBDWN_LASTVALUE, 0b00000001
	LPM		COUNTSECStemp, Z
	OUT		PORTD, COUNTSECStemp
	LD		COUNTDECStemp, X
	OUT		PORTD, COUNTDECStemp


	;Config. de TIMER0 en modo NORMAL e interrupciones
	;Sin necesidad de cambiar TCCR0A
	;Compare value: TCNT0 = 256-156.25 = 99.75 (10ms)
	LDI		R16, (1 << CS01) | (1 << CS00)		;Prescaler 64
	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, 100
	OUT		TCNT0, R16

	;Habilitación de Interrupciones en PCIE1 (PORTC)
	LDI		R16, (1 << PCIE1)
	STS		PCICR, R16
	LDI		R16, 0x03
	STS		PCMSK1, R16

	;Rehabilitamos interrupciones globales
	SEI
		
MAIN_LOOP:
	;Si COUNTMILLIS = 100: Aumentar COUNTDECS, COUNTSECS y reiniciar COUNTMILLIS
	CPI		COUNTMILLIS, 100
	BREQ	COUNTSECS_UP
	RJMP	MAIN_LOOP

	COUNTSECS_UP:
		CLR		COUNTMILLIS
		INC		COUNTSECS
		CPI		COUNTSECS, 10
		BREQ	COUNTSECS_CLEAR_AND_COUNTDECS_UP
		ADIW	Z, 1
		RJMP	MAIN_LOOP
	COUNTSECS_CLEAR_AND_COUNTDECS_UP:
		CLR		COUNTSECS
		LDI		ZL, LOW(DISP7SEG << 1)
		LDI		ZH, HIGH(DISP7SEG << 1)
		INC		COUNTDECS
		CPI		COUNTDECS, 6
		BREQ	COUNTDECS_CLEAR
		ADIW	X, 1
		RJMP	MAIN_LOOP
	COUNTDECS_CLEAR:
		CLR		COUNTDECS
		LDI		XL, LOW(DISP7SEG_RAM << 1)
		LDI		XH, HIGH(DISP7SEG_RAM << 1)
		RJMP	MAIN_LOOP



;********Sub-rutinas de interrupción******** 
TIMER_RESET_AND_DISPS_TOGGLE:
	;Reiniciamos TIMER0 e incrementamos COUNTMILLIS
	INC		COUNTMILLIS
	LDI		R16, 100
	OUT		TCNT0, R16
	SBI		PINC, 2		;Toggleamos el bit del transistor de DISPUNIS
	SBI		PINC, 3		;Toggleamos el bit del transistor de DISPDECS
	;Si el bit del transistor DISPUNIS está encendido: Cargamos DISPUNIS en PORTD
	;Si no: Cargamos DISPDECS en PORTD
	SBIS	PORTC, 2
	RJMP	COUNTDECS_SET
	LPM		COUNTSECStemp, Z
	OUT		PORTD, COUNTSECStemp
	TIMER_RETURN:
	RETI
	COUNTDECS_SET:
		LD		COUNTDECStemp, X
		OUT		PORTD, COUNTDECStemp
		RJMP	TIMER_RETURN


PIN_CHANGE:
;(Será utilizada la instrucción SEI para habilitar interrupciones anidadas)
	SEI		; Habilitamos interrupciones anidadas
	;Primero revisamos si el cambio fue en COUNTUP_BUTTON
	;Si el botón se encuentra presionado, nos vamos a revisar su estado anterior para verificar
	;si es correcto incrementar el valor de COUNT
	;Si el botón NO se encuentra presionado, establecemos su último estado como NO presionado,
	;y revisamos COUNTDWN_BUTTON
	SBIS		PINC, 1
	RJMP		COUNTUP_SEG
	LDI			PBUP_LASTVALUE, 0b00000001

	;Si el estado anterior de COUNTUP_BUTTON era el mismo que el último guardado, o bien, si el
	; botón NO se encontraba presionado, no ejecutamos un incremento y revisamos COUNTDWN_BUTTON
	;Si countDWN_BUTTON se encuentra presionado, nos vamos a revisar su estado anterior para verificar
	;si es correcto decrementar el valor de COUNT
	;Si el botón NO se encuentra presionado, establecemos su último estado como NO presionado,
	;y regresamos a MAIN saliéndonos de la rutina de interrupción
	RETURN_UP:
		SBIS		PINC, 0
		RJMP		COUNTDWN_SEG
		LDI			PBDWN_LASTVALUE, 0b00000001
	RETURN_DWN:
		RETI



;********Sub-rutinas de la sub-rutina de interrupción******** 
COUNTUP_SEG:
	BST		PBUP_LASTVALUE, 0
	BRTC	RETURN_UP
	CALL	COUNTUP
	LDI		PBUP_LASTVALUE,	0b00000000
	;No es necesario un loop de seguridad dado el uso de interrupciones
	RJMP		RETURN_UP
COUNTUP:
	INC		COUNT
	SBRS	COUNT, 4
	CLR		COUNT
	OUT		PORTB, COUNT
	RET	

COUNTDWN_SEG:
	BST		PBDWN_LASTVALUE, 0
	BRTC	RETURN_DWN
	CALL	COUNTDWN
	LDI		PBDWN_LASTVALUE,	0b00000000
	;No es necesario un loop de seguridad dado el uso de interrupciones
	RJMP		RETURN_DWN
COUNTDWN:
	DEC		COUNT
	SBRS	COUNT, 7
	LDI		COUNT, 0x0F
	OUT		PORTB, COUNT
	RET



