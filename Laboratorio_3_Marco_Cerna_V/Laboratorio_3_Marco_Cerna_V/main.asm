;*****************************************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Laboratorio #3: 
; Created: 17/02/2025 17:02:52
; Author : Marco Cerna V.
;*****************************************************************

.Include "M328PDEF.INC"

.ORG 0X0000        
    RJMP RESET       
.ORG PCI0addr         
    RJMP PCINT0_ISR   
.ORG OC0AADDR       
    RJMP TIMER0_COMPA_ISR ; 

; Definicion de variables
.DEF DIGITO_UNIDADES = R16 ; Dígito de unidades (display)
.DEF DIGITO_DECENAS  = R17 ; Dígito de decenas (display)
.DEF CONTADOR        = R18 ; Contador de tiempo
.DEF DISPLAY_ACTUAL  = R19 ; El display que se muestra
.DEF CONT_BINARIO    = R21 ; Contador binario para LEDs
.DEF TEMP            = R20 ; Registro temporal

;--------------------------------------
RESET:
    ; Inicializa stack
    LDI TEMP, LOW(RAMEND)
    OUT SPL, TEMP
    LDI TEMP, HIGH(RAMEND)
    OUT SPH, TEMP

    ; Configura PORTD como salida (displays)
    LDI TEMP, 0XFF
    OUT DDRD, TEMP
    CLR TEMP
    LDI TEMP, 0
    STS UCSR0B, TEMP
    OUT PORTD, TEMP

    ; Configura PORTC como salida (LEDs contador)
    LDI TEMP, 0X0F
    OUT DDRC, TEMP
    CLR TEMP
    OUT PORTC, TEMP

    ; Configura pines para transistores de los displays
    LDI TEMP, (1 << PB1) | (1 << PB2)
    OUT DDRB, TEMP
    CBI PORTB, PB1
    CBI PORTB, PB2

    ; Configura botones con pull-up interno
    CBI DDRB, PB3
    CBI DDRB, PB4
    SBI PORTB, PB3
    SBI PORTB, PB4

    ; Inicializa registros en 0
    LDI DIGITO_UNIDADES, 0
    LDI DIGITO_DECENAS, 0
    CLR CONTADOR
    CLR DISPLAY_ACTUAL
    LDI CONT_BINARIO, 0

    ; Configura interrupción de los botones
    LDI TEMP, (1 << PCIE0)
    STS PCICR, TEMP
    LDI TEMP, (1 << PCINT3) | (1 << PCINT4)
    STS PCMSK0, TEMP

    ; Configura Timer0 para interrupción cada 5ms
    LDI TEMP, (1 << WGM01)
    OUT TCCR0A, TEMP
    LDI TEMP, (1 << CS02) | (1 << CS00)
    OUT TCCR0B, TEMP
    LDI TEMP, 77
    OUT OCR0A, TEMP
    LDI TEMP, (1 << OCIE0A)
    STS TIMSK0, TEMP

    SEI ; Habilita interrupciones globales

MAIN_LOOP:
    ; Actualiza LEDs del contador binario
    MOV TEMP, CONT_BINARIO
    ANDI TEMP, 0X0F
    OUT PORTC, TEMP
    RJMP MAIN_LOOP

;--------------------------------------
; ISR para incremento/decremento con botones
;--------------------------------------
PCINT0_ISR:
    
    PUSH TEMP
    IN TEMP, SREG
    PUSH TEMP

    ; Incrementa si se presiona PB3
    SBIC PINB, PB3
    RJMP NO_INC
    INC CONT_BINARIO
NO_INC:

    ; Decrementa si se presiona PB4
    SBIC PINB, PB4
    RJMP NO_DEC
    DEC CONT_BINARIO
NO_DEC:

    ; Mantiene rango de 4 bits
    ANDI CONT_BINARIO, 0x0F

    POP TEMP
    OUT SREG, TEMP
    POP TEMP
    RETI
;--------------------------------------
; ISR para actualización de displays y conteo
;--------------------------------------

TIMER0_COMPA_ISR:
    PUSH TEMP
    IN TEMP, SREG
    PUSH TEMP

    ; Apaga displays y limpia segmentos
    CBI PORTB, PB1
    CBI PORTB, PB2
    CLR TEMP
    OUT PORTD, TEMP

    ;Lineas de retardo
    NOP
    NOP
    NOP

    ; Valida rango de unidades y decenas
    CPI DIGITO_UNIDADES, 10
    BRLO VALIDO_UNIDADES
    CLR DIGITO_UNIDADES

VALIDO_UNIDADES:
    CPI DIGITO_DECENAS, 6
    BRLO VALIDO_DECENAS
    CLR DIGITO_DECENAS

VALIDO_DECENAS:
    ; Alterna entre displays
    CPI DISPLAY_ACTUAL, 0
    BREQ MOSTRAR_UNIDADES

MOSTRAR_DECENAS:
    LDI DISPLAY_ACTUAL, 0
    MOV TEMP, DIGITO_DECENAS
    RCALL DISPLAY_ACTU
    SBI PORTB, PB2
    RJMP CONTAR_TIEMPO

MOSTRAR_UNIDADES:
    LDI DISPLAY_ACTUAL, 1
    MOV TEMP, DIGITO_UNIDADES
    RCALL DISPLAY_ACTU
    SBI PORTB, PB1

CONTAR_TIEMPO:
    ; Incrementa tiempo y actualiza dígitos
    INC CONTADOR
    CPI CONTADOR, 200
    BRNE SALIR_ISR
    CLR CONTADOR
    INC DIGITO_UNIDADES
    CPI DIGITO_UNIDADES, 10
    BRLO SALIR_ISR
    CLR DIGITO_UNIDADES
    INC DIGITO_DECENAS
    CPI DIGITO_DECENAS, 6
    BRLO SALIR_ISR
    CLR DIGITO_DECENAS
    CLR DIGITO_UNIDADES

SALIR_ISR:
    POP TEMP
    OUT SREG, TEMP
    POP TEMP
    RETI

;--------------------------------------
; Subrutina para actualizar los displays
;--------------------------------------
DISPLAY_ACTU:
    CPI TEMP, 0
    BREQ CERO
    CPI TEMP, 1
    BREQ UNO
    CPI TEMP, 2
    BREQ DOS
    CPI TEMP, 3
    BREQ TRES
    CPI TEMP, 4
    BREQ CUATRO
    CPI TEMP, 5
    BREQ CINCO
    CPI TEMP, 6
    BREQ SEIS
    CPI TEMP, 7
    BREQ SIETE
    CPI TEMP, 8
    BREQ OCHO
    CPI TEMP, 9
    BREQ NUEVE

    CLR TEMP
    RJMP DISP_OUT

CERO:   LDI TEMP, 0xC0 ; Patrón para 0
        RJMP DISP_OUT
UNO:    LDI TEMP, 0xF9 ; Patrón para 1
        RJMP DISP_OUT
DOS:    LDI TEMP, 0xA4 ; Patrón para 2
        RJMP DISP_OUT
TRES:   LDI TEMP, 0xB0 ; Patrón para 3
        RJMP DISP_OUT
CUATRO: LDI TEMP, 0x99 ; Patrón para 4
        RJMP DISP_OUT
CINCO:  LDI TEMP, 0x92 ; Patrón para 5
        RJMP DISP_OUT
SEIS:   LDI TEMP, 0x82 ; Patrón para 6
        RJMP DISP_OUT
SIETE:  LDI TEMP, 0xF8 ; Patrón para 7
        RJMP DISP_OUT
OCHO:   LDI TEMP, 0x80 ; Patrón para 8
        RJMP DISP_OUT
NUEVE:  LDI TEMP, 0x90 ; Patrón para 9

DISP_OUT:
    ; Actualiza PORTD (Displays)
    OUT PORTD, TEMP
    RET






