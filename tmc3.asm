;*************************************************************************
;	Tiny MIDI Converter 3 for PIC16F88
;-------------------------------------------------------------------------
;		Port A: 7 Seg.LED (A0-A4/A6,7)
;		Port B: 7 Seg.LED D.P. (B1)
;               MIDI IN(2) (B0)
;               MIDI IN(1) (B2)
;               Error LED (B3)
;               Mode Switch (B4)
;               MIDI OUT (B5)
;		P G M : B6,7
;=========================================================================
;                 $Id: tmc3.asm,v 1.12 2007/05/22 11:53:29 toyoshim Exp $
;*************************************************************************
	LIST    P=PIC16F88, R=DEC
	INCLUDE "P16F88.INC"
	__CONFIG	_CONFIG1,	_INTRC_IO & _WDT_OFF & _PWRTE_ON & _MCLR_ON & _BODEN_OFF & _LVP_OFF & _CPD_OFF & _WRT_PROTECT_OFF & _DEBUG_OFF & _CCP1_RB3 & _CP_OFF
	__CONFIG	_CONFIG2,	_FCMEN_OFF & _IESO_OFF

;*************************************************************************
; LED Patterns
;*************************************************************************
LED_PTN_0	SET		B'10100000'
LED_PTN_1	SET		B'11111001'
LED_PTN_2	SET		B'01100100'
LED_PTN_3	SET		B'01110000'
LED_PTN_4	SET		B'00111001'
LED_PTN_5	SET		B'00110010'
LED_PTN_6	SET		B'00100010'
LED_PTN_7	SET		B'11111000'
LED_PTN_8	SET		B'00100000'
LED_PTN_9	SET		B'00110000'
LED_PTN_A	SET		B'00101000'
LED_PTN_B	SET		B'00100011'
LED_PTN_C	SET		B'01100111'
LED_PTN_D	SET		B'01000001'
LED_PTN_E	SET		B'00100110'
LED_PTN_F	SET		B'00101110'

LED_PTN__	SET		B'00001000'

;*************************************************************************
; I/O Bit Names
;*************************************************************************
IO_DP		SET		H'1'
IO_ERR		SET		H'3'
IO_MODE		SET		H'4'
IO_MIDI_IN1	SET		H'2'
IO_MIDI_IN2	SET		H'0'
IO_MIDI_OUT	SET		H'5'

;*************************************************************************
; etc
;*************************************************************************
BUF_MASK	SET		H'1F'

;*************************************************************************
; Register Names
;*************************************************************************
; Bank 0
WAIT_CNT1	EQU		H'20'
WAIT_CNT2	EQU		H'21'

IN1_RC_PTR	EQU		H'22'
IN1_TX_PTR	EQU		H'23'

IN2_RC_PTR	EQU		H'24'
IN2_TX_PTR	EQU		H'25'

IO_BUF		EQU		H'26'

TMR0_CNT	EQU		H'27'

TX_LEN		EQU		H'28'
TX_RUN1		EQU		H'29'
TX_RUN2		EQU		H'2A'
TX_DATA		EQU		H'2B'
TX_CH		EQU		H'2C'
TX_STATE	EQU		H'2D'
; TX_STATE
;	1: next data is target channel
;   2: next data is note number of note on
;	3: next data is note number of note off
;	4: next data is velocity of note on
;	bit7: sending system message

RC_DATA		EQU		H'2E'
RC_STATE	EQU		H'2F'
; RC_STATE
;	0: normal
; 1~8: receiving bit 0~7
;	9: receiving stop bit

SYS_LEN		EQU		H'30'
TX_SYS_LEN	EQU		H'31'
TX_NOTE		EQU		H'32'
TX_VELO		EQU		H'33'

IN1_BUF		EQU		H'40'
IN1_BUF_END	EQU		H'5F'

LED_PTN		EQU		H'60'
LED_PTN_END	EQU		H'6F'

W_TEMP		EQU		H'70'
STATUS_TEMP	EQU		H'71'
PCLATH_TEMP	EQU		H'72'
FSR_TEMP	EQU		H'73'
PIE1_TEMP	EQU		H'74'
PORTB_TEMP	EQU		H'75'
INTCON_TEMP	EQU		H'76'

; Bank 1
IN2_BUF		EQU		H'A0'
IN2_BUF_END	EQU		H'BF'

; Bank 2
NOTE_BUF1	EQU		H'10'	; H'110'-H'14F'

; Bank 3
NOTE_BUF2	EQU		H'90'	; H'190'-H'1CF'

;*************************************************************************
; Reset Vector
;*************************************************************************
RESET
	ORG		0
    GOTO	INIT

;*************************************************************************
; Interrupt Vector
;*************************************************************************
; Start of Interrupt Handlers
INT
	ORG		4
	MOVWF	W_TEMP			; Save W Register
	SWAPF	STATUS, 0		; Save Status Register
	CLRF	STATUS			; Select Bank 0
	MOVWF	STATUS_TEMP
	MOVF	PCLATH, 0		; Save PC Latch
	MOVWF	PCLATH_TEMP
	CLRF	PCLATH			; PC Latch = 0
	MOVF	FSR, 0			; Save File Select Register
	MOVWF	FSR_TEMP

INT_START
	MOVF	PORTB, 0		; Save Port B
	MOVWF	PORTB_TEMP

	BSF		STATUS, RP0		; Select Bank 1
	MOVF	PIE1, 0
	MOVWF	PIE1_TEMP
	BCF		STATUS, RP0		; Select Bank 0
	MOVF	INTCON, 0
	MOVWF	INTCON_TEMP

;-------------------------------------------------------------------------
; Timer0 Reset
TMR0_RESET
	MOVLW	H'EC'
	BTFSC	INTCON_TEMP, TMR0IF	; TMR0 Interrupt?
	MOVWF	TMR0			; Adjust Timer0 Counter

;-------------------------------------------------------------------------
; External Interrupt Handler
INT_CHECK
	BTFSS	INTCON_TEMP, INTE	; INT Interrupt Enabled?
	GOTO	INT_NEXT
	BTFSS	INTCON_TEMP, INTF	; INT Interrupt?
	GOTO	INT_NEXT

INT_INT
	BCF		INTCON, INTF	; Reset INTF
	MOVLW	H'EA'
	MOVWF	TMR0			; Adjust Timer0 Counter
	BCF		INTCON, TMR0IF	; Reset TMR0IF
	BCF		INTCON_TEMP, TMR0IF
	MOVLW	H'01'
	MOVWF	RC_STATE		; RC_STATE = 1
	BCF		INTCON, INTE	; Disable INT Interrupt
INT_NEXT

;-------------------------------------------------------------------------
; Async. Receive Interrupt Handler
RC_CHECK
	BTFSS	PIR1, RCIF		; RC Interrupt?
	GOTO	RC_NEXT
	BTFSS	PIE1_TEMP, RCIE	; RC Interrupt Enabled?
	GOTO	RC_NEXT

RC_INT
	MOVF	IN1_RC_PTR, 0
	MOVWF	FSR				; Select Receive Buffer
	MOVF	RCREG, 0
	MOVWF	INDF			; Write to Receive Buffer

	INCF	IN1_RC_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN1_BUF
	MOVWF	IN1_RC_PTR		; IN1_RC_PTR = (IN1_RC_PTR + 1) & BUF_MASK + IN1_BUF

	SUBWF	IN1_TX_PTR, 0
	BTFSC	STATUS, Z		; (IN1_RC_PTR == IN1_TX_PTR)?
	BSF		IO_BUF, IO_ERR	; Enable Error LED (Buffer Overrun)
RC_NEXT

;-------------------------------------------------------------------------
; Timer0 Interrupt Handler
TMR0_CHECK
	BTFSS	INTCON_TEMP, TMR0IF	; TMR0 Interrupt?
	GOTO	TMR0_NEXT

TMR0_INT
	BCF		INTCON, TMR0IF	; Reset TMR0IF

	DECFSZ	TMR0_CNT, 1		; TMR0_CNT--
	GOTO	TMR0_RC_CHECK

TMR0_RESET_DP
	BSF		IO_BUF, IO_DP	; if (0 == TMR0_CNT) Disable DP LED

TMR0_RC_CHECK
	MOVF	RC_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TMR0_NEXT		; if (0 == RC_STATE) Goto TMR0_NEXT

TMR0_RC
	RRF		RC_DATA, 1		; RC_DATA >>= 1
	BCF		RC_DATA, 7		; RC_DATA &= 0x7F
	BTFSC	PORTB_TEMP, IO_MIDI_IN2
	BSF		RC_DATA, 7		; if (0 != (PORTB_TEMP & IO_MIDI_IN2)) RC_DATA |= 080
	INCF	RC_STATE, 1		; RC_STATE++
	MOVLW	H'09'
	SUBWF	RC_STATE, 0
	BTFSS	STATUS, Z
	GOTO	TMR0_NEXT		; if (9 != RC_STATE) Goto TMR0_NEXT

TMR0_RC_DONE
	MOVF	IN2_RC_PTR, 0
	MOVWF	FSR				; Select Receive Buffer
	MOVF	RC_DATA, 0
	MOVWF	INDF			; Write to Receive Buffer

	INCF	IN2_RC_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN2_BUF
	MOVWF	IN2_RC_PTR		; IN2_RC_PTR = (IN2_RC_PTR + 1) & BUF_MASK + IN2_BUF

	SUBWF	IN2_TX_PTR, 0
	BTFSC	STATUS, Z		; (IN2_RC_PTR == IN2_TX_PTR)?
	BSF		IO_BUF, IO_ERR	; Enable Error LED (Buffer Overrun)

	BCF		INTCON, INTF	; Reset INTF
	BSF		INTCON, INTE	; Enable INT Interrupt
	CLRF	RC_STATE		; RC_STATE = 0
TMR0_NEXT

;-------------------------------------------------------------------------
; End of Interrupt Handlers
RETI
	MOVF	IO_BUF, 0
	MOVWF	PORTB			; Flush Port B

	MOVF	FSR_TEMP, 0		; Restore File Select Register
	MOVWF	FSR
	MOVF	PCLATH_TEMP, 0	; Restore PC Latch
	MOVWF	PCLATH
	SWAPF	STATUS_TEMP, 0	; Restore Status Register
	MOVWF	STATUS
	SWAPF	W_TEMP, 1		; Restore W Register
	SWAPF	W_TEMP, 0
	RETFIE					; Return From Interrupt

;*************************************************************************
; System Len
;	W[in]
;	W[out]
;*************************************************************************
SYSTEM_LEN
	ANDLW	H'0F'
	BTFSC	STATUS, Z
	RETLW	H'FF'		; if (0xF0 == TX_DATA) Return -1
	SUBLW	H'03'
	BTFSC	STATUS, Z
	RETLW	H'02'		; if (0xF3 == TX_DATA) Return 2
	SUBLW	H'01'
	BTFSC	STATUS, Z
	RETLW	H'03'		; if (0xF2 == TX_DATA) Return 3
	ADDLW	H'01'
	BTFSC	STATUS, Z
	RETLW	H'02'		; if (0xF1 == TX_DATA) Return 2
	RETLW	H'01'		; else Return 1

;*************************************************************************
; Event Len
;	W[in]
;	W[out]
;*************************************************************************
EVENT_LEN
	ANDLW	H'F0'
	SUBLW	H'D0'
	BTFSC	STATUS, Z
	RETLW	H'02'		; if (0xD0 == (TX_DATA & 0xF0)) Return 2
	SUBLW	H'10'
	BTFSC	STATUS, Z
	RETLW	H'02'		; if (0xC0 == (TX_DATA & 0xF0)) Return 2
	RETLW	H'03'		; else Return 3

;*************************************************************************
; Wait A Moment
;*************************************************************************
WAIT
	CLRF	WAIT_CNT1
	CLRF	WAIT_CNT2
WAITL
	DECFSZ	WAIT_CNT2, 1
	GOTO	WAITL
	DECFSZ	WAIT_CNT1, 1
	GOTO	WAITL
	RETURN

;*************************************************************************
; Initialize
;*************************************************************************
INIT
	BCF		STATUS, RP0		; Select Bank 0
	CLRF	INTCON			; Disable All Interrupt

;-------------------------------------------------------------------------
; Init. I/O Ports
INIT_IO
	BSF		STATUS, RP0		; Select Bank 1
	CLRF	TRISA			; Port A is All Outputs except for A5
	MOVLW	B'00010101'		; Port B 0,2,4 are Inputs and 1,3,5 are Outputs
	MOVWF	TRISB
	CLRF	ANSEL			; Port A is Digital I/O

;-------------------------------------------------------------------------
; Init. Internal Oscillator
INIT_OSC
	BSF		STATUS, RP0		; Select Bank 1
	MOVLW	B'01110010'		; Internal Oscillator Frequency is 8MHz
	MOVWF	OSCCON

CHECK_OSC
	BTFSS	OSCCON, IOFS	; Wait for Stable Clock
;	GOTO	CHECK_OSC

;-------------------------------------------------------------------------
; Init. Variables on File Register
INIT_VAR
	BCF		STATUS, RP0		; Select Bank 0
	MOVLW	LED_PTN_0
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 0)
	MOVLW	LED_PTN_1
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 1)
	MOVLW	LED_PTN_2
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 2)
	MOVLW	LED_PTN_3
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 3)
	MOVLW	LED_PTN_4
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 4)
	MOVLW	LED_PTN_5
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 5)
	MOVLW	LED_PTN_6
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 6)
	MOVLW	LED_PTN_7
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 7)
	MOVLW	LED_PTN_8
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 8)
	MOVLW	LED_PTN_9
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 9)
	MOVLW	LED_PTN_A
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 10)
	MOVLW	LED_PTN_B
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 11)
	MOVLW	LED_PTN_C
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 12)
	MOVLW	LED_PTN_D
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 13)
	MOVLW	LED_PTN_E
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 14)
	MOVLW	LED_PTN_F
	MOVWF	PORTA
	CALL	WAIT
	MOVWF	(LED_PTN + 15)

	MOVLW	IN1_BUF
	MOVWF	IN1_RC_PTR		; Init Read Pointer 1
	MOVWF	IN1_TX_PTR		; Init Write Pointer 1
	MOVLW	IN2_BUF
	MOVWF	IN2_RC_PTR		; Init Read Pointer 2
	MOVWF	IN2_TX_PTR		; Init Write Pointer 2

	CLRF	TX_RUN1			; Init Running Status 1
	CLRF	TX_RUN2			; Init Running Status 2
	CLRF	TX_STATE		; Init State for Transmit Filters
	CLRF	TX_CH			; Init Ch.ID for Transmit Channel Filter
	CLRF	RC_STATE		; Init State for MIDI IN(2) Receive

;-------------------------------------------------------------------------
; Init. Output Ports
INIT_PORT
	BCF		STATUS, RP0		; Select Bank 0
	CLRF	PORTA			; Enable All LEDs
	CLRF	PORTB

	CALL	WAIT			; Wait A Minutes
	CALL	WAIT
	CALL	WAIT
	CALL	WAIT
	CALL	WAIT

	MOVLW	LED_PTN_0
	MOVWF	PORTA			; Display '0'
	MOVLW	B'00000010'		; Disable All LEDs
	MOVWF	PORTB
	MOVWF	IO_BUF

;-------------------------------------------------------------------------
; Init. UART
INIT_UART
	BSF		STATUS, RP0		; Select Bank 1
	MOVLW	H'03'			; Baud Rate = 8MHz / (64 * (3 + 1)) = 31.25kHz
	MOVWF	SPBRG

	MOVLW	B'00100000'		; Asynchronous Mode / Low Speed / Transmit Enable
	MOVWF	TXSTA

	BCF		STATUS, RP0		; Select Bank 0
	MOVLW	B'10010000'		; Serial Port Enable / Continuous Receive Enable / Receive Enable
	MOVWF	RCSTA

;-------------------------------------------------------------------------
; Init. Timer0
INIT_TMR0
	BSF		STATUS, RP0		; Select Bank 1
	MOVLW	B'10000000'		; Port B Pull-ups are disabled
							; Interrupt on falling edge of INT pin
							; TMR0 Clock Source is Internal instruction cycle clock
							; Prescaler is assigned to the Timer0 module
							; Prescaler Rate is 1:2 (1MHz)
	MOVWF	OPTION_REG
	BCF		STATUS, RP0		; Select Bank 0
	MOVLW	H'E0'
	MOVWF	TMR0			; TMR0 = 0xE0

;-------------------------------------------------------------------------
; Init. External Interrupt
INIT_INT
	BSF		STATUS, RP0		; Select Bank 1
	BSF		PIE1, RCIE		; Receive Interrupt Enable
	BCF		PIE1, TXIE		; Transmit Interrupt Disable
	BCF		STATUS, RP0		; Select Bank 0
	MOVLW	B'11110000'		; Global Interrupt Enable
							; Peripheral Interrupt Enable
							; TMR0 Interrupt Enable
							; INT Externel Interrupt Enable
;	BTFSC	PORTB, IO_MODE
;	MOVLW	B'11100000'		; Global Interrupt Enable
							; Peripheral Interrupt Enable
							; TMR0 Interrupt Enable
							; INT Externel Interrupt Disable
	MOVWF	INTCON
	BTFSC	PORTB, IO_MODE
	BSF		PORTB, IO_ERR

;*************************************************************************
; Main Loop
;*************************************************************************
MAIN
	BCF		STATUS, RP0		; Select Bank 0

MIDI_IN2_DONE
;-------------------------------------------------------------------------
; MIDI IN(1) to MIDI OUT
MIDI_IN1_CHECK
	MOVF	IN1_RC_PTR, 0
	SUBWF	IN1_TX_PTR, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN1_DONE	; if (IN1_RC_PTR == IN1_TX_PTR) Goto MIDI_IN1_DONE

;-------------------------------------------------------------------------
; MIDI IN(1); Check Message Type
MIDI_IN1_SEND
	MOVF	IN1_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	ANDLW	H'80'
	BTFSC	STATUS, Z
	GOTO	MIDI_IN1_RUN	; if (0 == (TX_DATA & 0x80)) Goto MIDI_IN1_RUN

	MOVF	TX_DATA, 0
	ANDLW	H'F0'
	SUBLW	H'F0'
	BTFSS	STATUS, Z
	GOTO	MIDI_IN1_EVENT	; if (0xF0 != (TX_DATA & 0xF0)) Goto MIDI_IN1_EVENT

;-------------------------------------------------------------------------
; MIDI IN(1); System Message
MIDI_IN1_NORMAL_SYSTEM
	CALL	MIDI_IN1_SYS
	GOTO	MIDI_IN1_DONE

;-------------------------------------------------------------------------
; MIDI IN(1); Channel Message
MIDI_IN1_EVENT
	MOVF	TX_DATA, 0
	MOVWF	TX_RUN1			; Save for Running Status

	INCF	IN1_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN1_BUF
	MOVWF	IN1_TX_PTR		; IN1_TX_PTR = (IN1_TX_PTR + 1) & BUF_MASK + IN1_BUF

	MOVF	TX_DATA, 0
	GOTO	MIDI_IN1_SENDCALL

;-------------------------------------------------------------------------
; MIDI IN(1); Invalid Message
MIDI_IN1_INVALID
	INCF	IN1_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN1_BUF
	MOVWF	IN1_TX_PTR		; IN1_TX_PTR = (IN1_TX_PTR + 1) & BUF_MASK + IN1_BUF
	GOTO	MIDI_IN1_DONE

;-------------------------------------------------------------------------
; MIDI IN(1); Channel Message (Running Status)
MIDI_IN1_RUN
	MOVF	TX_RUN1, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN1_INVALID
	MOVWF	TX_DATA			; Load Running Status

MIDI_IN1_SENDCALL
	CALL	EVENT_LEN
	MOVWF	TX_LEN
	CALL	MIDI_SEND

MIDI_IN1_LENCHECK
	DECF	TX_LEN, 1
	BTFSC	STATUS, Z
	GOTO	MIDI_IN1_DONE	; if (0 == TX_LEN) Goto MIDI_IN1_DONE

MIDI_IN1_PARAMS
	MOVF	IN1_RC_PTR, 0
	SUBWF	IN1_TX_PTR, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN1_PARAMS	; if (IN1_RC_PTR == IN1_TX_PTR) Goto MIDI_IN1_PARAMS

	MOVF	IN1_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	ANDLW	H'F0'
	SUBLW	H'F0'
	BTFSS	STATUS, Z		; if (0xF0 != (TX_DATA & 0xF0)) Goto MIDI_IN1_SEND_PARAMS
	GOTO	MIDI_IN1_SEND_PARAMS

MIDI_IN1_INT_SYSTEM
	CALL	MIDI_IN1_SYS
	GOTO	MIDI_IN1_PARAMS

MIDI_IN1_SEND_PARAMS
	CALL	MIDI_SEND_PARAM

	INCF	IN1_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN1_BUF
	MOVWF	IN1_TX_PTR		; IN1_TX_PTR = (IN1_TX_PTR + 1) & BUF_MASK + IN1_BUF
	GOTO	MIDI_IN1_LENCHECK

;-------------------------------------------------------------------------
; MIDI IN(1); System Message Subroutine
MIDI_IN1_SYS
	MOVF	TX_DATA, 0
	CALL	SYSTEM_LEN
	MOVWF	SYS_LEN

MIDI_IN1_SYS_LOOP
	CALL	MIDI_SEND_PARAM

	INCF	IN1_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN1_BUF
	MOVWF	IN1_TX_PTR		; IN1_TX_PTR = (IN1_TX_PTR + 1) & BUF_MASK + IN1_BUF

	DECF	SYS_LEN, 1
	BTFSC	STATUS, Z
	RETURN					; if (0 == SYS_LEN) Return

	MOVF	TX_DATA, 0
	SUBLW	H'F7'
	BTFSC	STATUS, Z
	RETURN					; if (0xF7 == TX_DATA) Return

MIDI_IN1_SYS_WAIT
	MOVF	IN1_RC_PTR, 0
	SUBWF	IN1_TX_PTR, 0
	BTFSC	STATUS, Z		; if (IN1_RC_PTR == IN1_TX_PTR) Goto MIDI_IN1_SYS_WAIT
	GOTO	MIDI_IN1_SYS_WAIT

	MOVF	IN1_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	GOTO	MIDI_IN1_SYS_LOOP
MIDI_IN1_DONE

;-------------------------------------------------------------------------
; MIDI IN(2) to MIDI OUT
MIDI_IN2_CHECK
	MOVF	IN2_RC_PTR, 0
	SUBWF	IN2_TX_PTR, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN2_DONE	; if (IN2_RC_PTR == IN2_TX_PTR) Goto MIDI_IN2_DONE

;-------------------------------------------------------------------------
; MIDI IN(2); Check Message Type
MIDI_IN2_SEND
	MOVF	IN2_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	ANDLW	H'80'
	BTFSC	STATUS, Z
	GOTO	MIDI_IN2_RUN	; if (0 == (TX_DATA & 0x80)) Goto MIDI_IN2_RUN

	MOVF	TX_DATA, 0
	ANDLW	H'F0'
	SUBLW	H'F0'
	BTFSS	STATUS, Z
	GOTO	MIDI_IN2_EVENT	; if (0xF0 != (TX_DATA & 0xF0)) Goto MIDI_IN2_EVENT

;-------------------------------------------------------------------------
; MIDI IN(2); System Message
MIDI_IN2_NORMAL_SYSTEM
	CALL	MIDI_IN2_SYS
	GOTO	MIDI_IN2_DONE

;-------------------------------------------------------------------------
; MIDI IN(2); Channel Message
MIDI_IN2_EVENT
	MOVF	TX_DATA, 0
	MOVWF	TX_RUN2			; Save for Running Status

	INCF	IN2_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN2_BUF
	MOVWF	IN2_TX_PTR		; IN2_TX_PTR = (IN2_TX_PTR + 1) & BUF_MASK + IN2_BUF

	MOVF	TX_DATA, 0
	GOTO	MIDI_IN2_SENDCALL

;-------------------------------------------------------------------------
; MIDI IN(2); Invalid Message
MIDI_IN2_INVALID
	INCF	IN2_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN2_BUF
	MOVWF	IN2_TX_PTR		; IN1_TX_PTR = (IN1_TX_PTR + 1) & BUF_MASK + IN1_BUF
	GOTO	MIDI_IN2_DONE

;-------------------------------------------------------------------------
; MIDI IN(2); Channel Message (Running Status)
MIDI_IN2_RUN
	MOVF	TX_RUN2, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN2_INVALID
	MOVWF	TX_DATA			; Load Running Status

MIDI_IN2_SENDCALL
	CALL	EVENT_LEN
	MOVWF	TX_LEN
	CALL	MIDI_SEND

MIDI_IN2_LENCHECK
	DECF	TX_LEN, 1
	BTFSC	STATUS, Z
	GOTO	MIDI_IN2_DONE	; if (0 == TX_LEN) Goto MIDI_IN2_DONE

MIDI_IN2_PARAMS
	MOVF	IN2_RC_PTR, 0
	SUBWF	IN2_TX_PTR, 0
	BTFSC	STATUS, Z
	GOTO	MIDI_IN2_PARAMS	; if (IN2_RC_PTR == IN2_TX_PTR) Goto MIDI_IN2_PARAMS

	MOVF	IN2_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	ANDLW	H'F0'
	SUBLW	H'F0'
	BTFSS	STATUS, Z		; if (0xF0 != (TX_DATA & 0xF0)) Goto MIDI_IN2_SEND_PARAMS
	GOTO	MIDI_IN2_SEND_PARAMS

MIDI_IN2_INT_SYSTEM
	CALL	MIDI_IN2_SYS
	GOTO	MIDI_IN2_PARAMS

MIDI_IN2_SEND_PARAMS
	CALL	MIDI_SEND_PARAM

	INCF	IN2_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN2_BUF
	MOVWF	IN2_TX_PTR		; IN2_TX_PTR = (IN2_TX_PTR + 1) & BUF_MASK + IN2_BUF
	GOTO	MIDI_IN2_LENCHECK

;-------------------------------------------------------------------------
; MIDI IN(2); System Message Subroutine
MIDI_IN2_SYS
	MOVF	TX_DATA, 0
	CALL	SYSTEM_LEN
	MOVWF	SYS_LEN

MIDI_IN2_SYS_LOOP
	CALL	MIDI_SEND_PARAM

	INCF	IN2_TX_PTR, 0
	ANDLW	BUF_MASK
	ADDLW	IN2_BUF
	MOVWF	IN2_TX_PTR		; IN2_TX_PTR = (IN2_TX_PTR + 1) & BUF_MASK + IN2_BUF

	DECF	SYS_LEN, 1
	BTFSC	STATUS, Z
	RETURN					; if (0 == SYS_LEN) Return

	MOVF	TX_DATA, 0
	SUBLW	H'F7'
	BTFSC	STATUS, Z
	RETURN					; if (0xF7 == TX_DATA) Return

MIDI_IN2_SYS_WAIT
	MOVF	IN2_RC_PTR, 0
	SUBWF	IN2_TX_PTR, 0
	BTFSC	STATUS, Z		; if (IN2_RC_PTR == IN2_TX_PTR) Goto MIDI_IN2_SYS_WAIT
	GOTO	MIDI_IN2_SYS_WAIT

	MOVF	IN2_TX_PTR, 0
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	TX_DATA			; Load Transmit Data to TX_DATA

	GOTO	MIDI_IN2_SYS_LOOP

;*************************************************************************
; MIDI Send
;	TX_DATA[in]
;*************************************************************************
MIDI_SEND
	CLRF	TMR0_CNT
	BCF		IO_BUF, IO_DP	; Counter Clear and Display '.'

MIDI_SEND_PARAM
MIDI_SEND_CHECK_UNDER_SYSTEM
	BTFSC	TX_STATE, 7
	GOTO	CASE_UNDER_SYSTEM

	MOVF	TX_DATA, 0
	ANDLW	H'F0'
	SUBLW	H'F0'
	BTFSS	STATUS, Z
	GOTO	CASE_STATE_0

	MOVF	TX_DATA, 0
	CALL	SYSTEM_LEN
	MOVWF	TX_SYS_LEN
	BSF		TX_STATE, 7
	GOTO	CASE_UNDER_SYSTEM

;-------------------------------------------------------------------------
; case 0: Send Normal Data with Filter Check
CASE_STATE_0
	MOVF	TX_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TX_FILTER_CHECK

;-------------------------------------------------------------------------
; case 1: Get Channel ID
CASE_STATE_1
	DECF	TX_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TX_GET_CH

;-------------------------------------------------------------------------
; case 2: Get Note Number
CASE_STATE_2
	DECF	TX_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TX_GET_NOTE

;-------------------------------------------------------------------------
; case 3: Detect Note Off Channel
CASE_STATE_3
	DECF	TX_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TX_NOTEOFF

;-------------------------------------------------------------------------
; case 4: Get Note On Velocity
CASE_STATE_4
	DECF	TX_STATE, 1
	BTFSC	STATUS, Z
	GOTO	TX_GET_VELOCITY

;-------------------------------------------------------------------------
; default: Send Normal Data without Filter Check
CASE_STATE_X
	GOTO	TX_SEND

;-------------------------------------------------------------------------
; case 0x8X: Send System Message
CASE_UNDER_SYSTEM
	DECF	TX_SYS_LEN, 1	; TX_SYS_LEN--
	BTFSC	STATUS, Z
	GOTO	CASE_UNDER_SYSTEM_LAST
	MOVF	TX_DATA, 0
	SUBLW	H'F7'
	BTFSS	STATUS, Z
	GOTO	TX_SEND

CASE_UNDER_SYSTEM_LAST
	BCF		TX_STATE, 7
	GOTO	TX_SEND

;-------------------------------------------------------------------------
; Get Channel ID
TX_GET_CH
	MOVF	TX_DATA, 0
	ANDLW	H'0F'
	MOVWF	TX_CH			; TX_CH = TX_DATA & 0x0F
	ADDLW	LED_PTN
	MOVWF	FSR
	MOVF	INDF, 0
	MOVWF	PORTA			; Show Channel ID on LED
	RETURN

;-------------------------------------------------------------------------
; Get Note Number
TX_GET_NOTE
	MOVF	TX_DATA, 0
	MOVWF	TX_NOTE			; TX_NOTE = TX_DATA
	MOVLW	H'04'
	MOVWF	TX_STATE		; TX_STATE = 4
	RETURN

;-------------------------------------------------------------------------
; Detect Note Off Channel
TX_NOTEOFF
	MOVF	TX_DATA, 0
	MOVWF	TX_NOTE
	MOVWF	FSR
	BTFSC	TX_DATA, 6
	BSF		FSR, 7
	BCF		FSR, 6			; FSR = ((TX_DATA & 0x40) << 1) | (TX_DATA & 0x3F)
	MOVLW	NOTE_BUF1
	ADDWF	FSR, 1			; FSR += NOTE_BUF1
	BSF		STATUS, IRP		; Select Bank 2,3 as Indirect Addressing
	MOVF	INDF, 0			; W = (FSR)
	BCF		STATUS, IRP		; Select Bank 0,1 as Indirect Addressing
	IORLW	H'80'
	MOVWF	TX_DATA			; TX_DATA = W | 0x80
	CALL	TX_SEND
	MOVF	TX_NOTE, 0
	MOVWF	TX_DATA
	GOTO	TX_SEND

;-------------------------------------------------------------------------
; Get Note On Velocity
TX_GET_VELOCITY
	MOVF	TX_DATA, 1
	BTFSC	STATUS, Z
	GOTO	TX_VELOCITY_ZERO

TX_VELOCITY_NOT_ZERO
	MOVF	TX_DATA, 0
	MOVWF	TX_VELO
	MOVF	TX_NOTE, 0
	MOVWF	FSR
	BTFSC	TX_NOTE, 6
	BSF		FSR, 7
	BCF		FSR, 6			; FSR = ((TX_NOTE & 0x40) << 1) | (TX_NOTE & 0x3F)
	MOVLW	NOTE_BUF1
	ADDWF	FSR, 1			; FSR += NOTE_BUF1
	MOVF	TX_CH, 0
	BSF		STATUS, IRP		; Select Bank 2,3 as Indirect Addressing
	MOVWF	INDF			; (FSR) = TX_CH
	BCF		STATUS, IRP		; Select Bank 0,1 as Indirect Addressing
	IORLW	H'90'
	MOVWF	TX_DATA			; TX_DATA = W | 0x90
	CALL	TX_SEND

	MOVF	TX_NOTE, 0
	MOVWF	TX_DATA
	CALL	TX_SEND

	MOVF	TX_VELO, 0
	MOVWF	TX_DATA
	GOTO	TX_SEND

TX_VELOCITY_ZERO
	MOVF	TX_NOTE, 0
	MOVWF	FSR
	BTFSC	TX_NOTE, 6
	BSF		FSR, 7
	BCF		FSR, 6			; FSR = ((TX_NOTE & 0x40) << 1) | (TX_NOTE & 0x3F)
	MOVLW	NOTE_BUF1
	ADDWF	FSR, 1			; FSR += NOTE_BUF1
	BSF		STATUS, IRP		; Select Bank 2,3 as Indirect Addressing
	MOVF	INDF, 0			; W = (FSR)
	BCF		STATUS, IRP		; Select Bank 0,1 as Indirect Addressing
	IORLW	H'90'
	MOVWF	TX_DATA			; TX_DATA = W | 0x90
	CALL	TX_SEND

	MOVF	TX_NOTE, 0
	MOVWF	TX_DATA
	CALL	TX_SEND

	CLRF	TX_DATA
	GOTO	TX_SEND

;-------------------------------------------------------------------------
; Filter Check
TX_FILTER_CHECK
	MOVF	TX_DATA, 0
	ANDLW	H'80'
	BTFSC	STATUS, Z
	GOTO	TX_SEND			; if (0 == (TX_DATA & 0x80)) Goto TX_SEND

TX_FILTER
	MOVF	TX_DATA, 0
	SUBLW	H'CF'
	BTFSC	STATUS, Z
	GOTO	TX_CF			; Channel Change on MIDI Channel 16

	MOVF	TX_DATA, 0
	SUBLW	H'9F'
	BTFSC	STATUS, Z
	GOTO	TX_9F			; Note On on MIDI Channel 16

	MOVF	TX_DATA, 0
	SUBLW	H'8F'
	BTFSC	STATUS, Z
	GOTO	TX_8F			; Note Off on MIDI Channel 16

;-------------------------------------------------------------------------
; Channel Filter
TX_CHANGE_CH
	MOVF	TX_DATA, 0
	ANDLW	H'0F'
	SUBLW	H'0F'
	BTFSS	STATUS, Z
	GOTO	TX_SEND			; if (0x0F != (TX_DATA & 0x0F)) Goto TX_SEND

	MOVF	TX_DATA, 0		; Change MIDI Channel to TX_CH
	ANDLW	H'F0'
	MOVWF	TX_DATA
	MOVF	TX_CH, 0
	ADDWF	TX_DATA, 1		; TX_DATA = (TX_DATA & 0xF0) + TX_CH
	GOTO	TX_SEND

;-------------------------------------------------------------------------
; Channel Change Filter
TX_CF
	MOVLW	H'01'
	MOVWF	TX_STATE		; TX_STATE = 1
	RETURN

;-------------------------------------------------------------------------
; Note On Channel Filter
TX_9F
	MOVLW	H'02'
	MOVWF	TX_STATE		; TX_STATE = 2
	RETURN

;-------------------------------------------------------------------------
; Note Off Channel Filter
TX_8F
	MOVLW	H'03'
	MOVWF	TX_STATE		; TX_STATE = 3
	RETURN

;-------------------------------------------------------------------------
; Send Data
TX_SEND
	BTFSS	PIR1, TXIF
	GOTO	MIDI_SEND

	MOVF	TX_DATA, 0
	MOVWF	TXREG			; Write to Transmit Buffer / Reset TXIF
	RETURN

	END
