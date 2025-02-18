;
; Lab03.asm
;
; Created: 17/02/2025 16:54:59
; Author : ang50
;


.include "M328PDEF.inc"
.cseg

.org 0x0000
	RJMP SETUP

;Guardamos un salto a la sub-rutina "PIN_CHANGE" en el vector de interrupci�n necesario
.org PCI1addr ;Pin Change Interrupt 1 (PORTC)
	RJMP	PIN_CHANGE

.org  OVF0addr
	RJMP TIMER_RESET

;Establecer direcci�n en program mem. LUEGO de los vectores de interrupci�n de TIM0
.org 0x0022
DISP7SEG:	
	.DB	0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x67, 0x77, 0x7C, 0x39, 0x5E, 0x79, 0x71

;Definici�n de registros importantes
.def	COUNTMILLIS		= R19
.def	BINDISP			= R20
.def	BINDISPtemp		= R21
.def	COUNT			= R22
;.def	COUNTtemp		= R21
.def	PBUP_LASTVALUE	= R23
.def	PBDWN_LASTVALUE	= R24

SETUP:
	;Deshabilitar interrupciones globales en el SETUP
	CLI

	;Establecemos el ZPointer en la direcci�n de DISP7SEG
	LDI		ZL, LOW(DISP7SEG << 1)
	LDI		ZH, HIGH(DISP7SEG << 1)
	
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

	;Deshabilitar serial (Importante; se utilizar� PD para el display)
	LDI		R16, 0x00
	STS		UCSR0B, R16

	;Configurar I/O PORTS (DDRx, PORTx)
	;PORTD: BINDISP Out (PD0,1,2,3,4,5,6)		|	PORTD: 0XXXXXXX
	LDI		R16, 0b11111111
	OUT		DDRD, R16
	LDI		R16, 0b00000000
	OUT		PORTD, R16
	;PORTB: BIN Out (PB0,1,2,3)								|	PORTB: 0000XXXX
	LDI		R16, 0x0F
	OUT		DDRB, R16
	LDI		R16, 0x00
	OUT		PORTB, R16
	;PORTC: BIN In (PC0,1)									|	PORTC: 00000011
	LDI		R16, 0
	OUT		DDRC, R16
	LDI		R16, 0b00000011
	OUT		PORTC, R16

	;Valores iniciales de registros importantes
	LDI		COUNT, 0
	LDI		COUNTMILLIS, 0x00
	LDI		BINDISP, 0x00
	LDI		PBUP_LASTVALUE, 0b00000001
	LDI		PBDWN_LASTVALUE, 0b00000001
	LPM		BINDISPtemp, Z
	OUT		PORTD, BINDISPtemp

	;Config. de TIMER0 en modo NORMAL e interrupciones
	;Sin necesidad de cambiar TCCR0A
	;Compare value: TCNT0 = 256-156.25 = 99.75 (10ms)
	LDI		R16, (1 << CS01) | (1 << CS00)		;Prescaler 64
	OUT		TCCR0B, R16
	LDI		R16, (1 << TOIE0) 
	STS		TIMSK0, R16
	LDI		R16, 100
	OUT		TCNT0, R16

	;Habilitaci�n de Interrupciones en PCIE1 (PORTC)
	LDI		R16, (1 << PCIE1)
	STS		PCICR, R16
	LDI		R16, 0x03
	STS		PCMSK1, R16

	;Rehabilitamos interrupciones globales
	SEI
		
MAIN_LOOP:
	;Si COUNTMILLIS = 100: Aumentar BINDISP y reiniciar COUNTMILLIS
	CPI		COUNTMILLIS, 100
	BREQ	BINDISP_UP
	RJMP	MAIN_LOOP

	BINDISP_UP:
		CLR		COUNTMILLIS
		INC		BINDISP
		CPI		BINDISP, 10
		BREQ	BINDISP_CLEAR
		ADIW	Z, 1
		LPM		BINDISPtemp, Z
		OUT		PORTD, BINDISPtemp
		RJMP	MAIN_LOOP

	BINDISP_CLEAR:
		CLR		BINDISP
		LDI		ZL, LOW(DISP7SEG << 1)
		LDI		ZH, HIGH(DISP7SEG << 1)
		LPM		BINDISPtemp, Z
		OUT		PORTD, BINDISPtemp
		RJMP	MAIN_LOOP



;********Sub-rutinas de interrupci�n******** 
TIMER_RESET:
	;Reiniciamos TIMER0 e incrementamos COUNTMILLIS
	INC		COUNTMILLIS
	LDI		R16, 100
	OUT		TCNT0, R16
	RETI

PIN_CHANGE:
;(Ser� utilizada la instrucci�n SEI para habilitar interrupciones anidadas)
	SEI		; Habilitamos interrupciones anidadas
	;Primero revisamos si el cambio fue en COUNTUP_BUTTON
	;Si el bot�n se encuentra presionado, nos vamos a revisar su estado anterior para verificar
	;si es correcto incrementar el valor de COUNT
	;Si el bot�n NO se encuentra presionado, establecemos su �ltimo estado como NO presionado,
	;y revisamos COUNTDWN_BUTTON
	SBIS		PINC, 1
	RJMP		COUNTUP_SEG
	LDI			PBUP_LASTVALUE, 0b00000001

	;Si el estado anterior de COUNTUP_BUTTON era el mismo que el �ltimo guardado, o bien, si el
	; bot�n NO se encontraba presionado, no ejecutamos un incremento y revisamos COUNTDWN_BUTTON
	;Si countDWN_BUTTON se encuentra presionado, nos vamos a revisar su estado anterior para verificar
	;si es correcto decrementar el valor de COUNT
	;Si el bot�n NO se encuentra presionado, establecemos su �ltimo estado como NO presionado,
	;y regresamos a MAIN sali�ndonos de la rutina de interrupci�n
	RETURN_UP:
		SBIS		PINC, 0
		RJMP		COUNTDWN_SEG
		LDI			PBDWN_LASTVALUE, 0b00000001
	RETURN_DWN:
		RETI



;********Sub-rutinas de la sub-rutina de interrupci�n******** 
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



