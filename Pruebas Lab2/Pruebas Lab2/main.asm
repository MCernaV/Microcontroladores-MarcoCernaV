;*************************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Proyecto: Lab 2: Display de 7 segmentos con cátodo comun
; Created: 11/02/2025 05:54:14
; Author : Marco Cerna V.
; Descripción: Este programa realiza el prelab del laboratorio #2
;*************************************************

.include "m328Pdef.inc"

; ==============================
; Definición de registros
; ==============================
.def temp = r16
.def CONTADOR = r17         ; Contador de 4 bits
.def CONTADOR2 = r22        ; Contador del display
.def EstadoBoton = r18      ; Estado actual de los botones
.def Estado_AntB1 = r19     ; Estado anterior del botón 1
.def Estado_AntB2 = r20     ; Estado anterior del botón 2
.def ANTIREBOTE_TEMP = r21  ; Temporal para el antirebote
.def OVERFLOW_CONT = r23    ; Contador de desbordamientos del Timer0

.equ B1 = 3    
.equ B2 = 4    
.equ LED_ALARMA = 4 
.equ PRELOAD = 6  ; Valor para 100ms en Timer0

.cseg
.org 0x00
    RJMP setup

; ------------------------------
; Tabla de segmentos
; ------------------------------
TABLA_SEGMENTOS:
.DB 0b0111111, 0b0000110, 0b1011011, 0b1001111, 0b1100110, 0b1101101, 0b1111101, 0b0000111, 0b1111111, 0b1101111, 0b1110111, 0b1111100, 0b0111001, 0b1011110, 0b1111001, 0b1110001


; ------------------------------
; Configuración inicial
; ------------------------------
setup:

    LDI temp, high(RAMEND)
    OUT SPH, temp
    LDI temp, low(RAMEND)
    OUT SPL, temp

    ; Configurar Pull-ups para los botones (PB3 y PB4)
    LDI temp, 0x00
    OUT DDRB, temp
    LDI temp, (1 << B1) | (1 << B2)
    OUT PORTB, temp
	LDI R25, 0x00
	STS UCSR0B, R25

    ; Configurar PORTD (salida para el display 7 segmentos)
    LDI temp, 0xFF
    OUT DDRD, temp

    ; Configurar PORTC (salida para LED en PC4/A4)
    LDI temp, (1 << LED_ALARMA)
    OUT DDRC, temp

    ; Configurar Timer0 (Prescaler 1024)
    LDI temp, (1 << CS02) | (1 << CS00)
    OUT TCCR0B, temp

    ; Cargar PRELOAD en Timer0 para 100ms
    LDI temp, PRELOAD
    OUT TCNT0, temp

    CLR CONTADOR
    CLR CONTADOR2
    CLR OVERFLOW_CONT
    SER Estado_AntB1
    SER Estado_AntB2

    RCALL MOSTRAR_NUM

; ------------------------------
; Bucle principal
; ------------------------------
MAIN:

ESPERAR_DES:
    IN temp, TIFR0
    SBRC temp, TOV0
    RJMP OVERFLOW
    RJMP ESPERAR_DES

; ------------------------------
; Manejo del desbordamiento del Timer0
; ------------------------------
OVERFLOW:
    LDI temp, (1 << TOV0)
    OUT TIFR0, temp

    INC OVERFLOW_CONT


    CPI OVERFLOW_CONT, 10 ; Comparar numero de desbordamientos 
    BRLO SKIP_CONTADOR


    CLR OVERFLOW_CONT
    INC CONTADOR2
    ANDI CONTADOR2, 0x0F
    OUT PORTC, CONTADOR2

    
    CP CONTADOR2, CONTADOR ; Comparar CONTADOR2 con CONTADOR
    BRNE SKIP_LED
    CLR CONTADOR2
    SBI PINC, LED_ALARMA

SKIP_LED:
SKIP_CONTADOR:

    LDI temp, PRELOAD
    OUT TCNT0, temp     ; Recargar Timer0

    RCALL CHECK_BOTONES
    RJMP MAIN

; ------------------------------
; Leer y procesar los botones
; ------------------------------
CHECK_BOTONES:
    IN EstadoBoton, PINB

    MOV ANTIREBOTE_TEMP, EstadoBoton
    COM ANTIREBOTE_TEMP
    ANDI ANTIREBOTE_TEMP, (1 << B1)
    BREQ SALTAR_B1
    SBRC Estado_AntB1, B1
    RCALL INCREMENTO

SALTAR_B1:

    MOV ANTIREBOTE_TEMP, EstadoBoton
    COM ANTIREBOTE_TEMP
    ANDI ANTIREBOTE_TEMP, (1 << B2)
    BREQ SALTAR_B2
    SBRC Estado_AntB2, B2
    RCALL DECREMENTO

SALTAR_B2:

    MOV Estado_AntB1, EstadoBoton
    MOV Estado_AntB2, EstadoBoton

    RET

; ------------------------------
; Incrementar Contador
; ------------------------------
INCREMENTO:
    RCALL DELAY_ANTIREBOTE
    INC CONTADOR
    CPI CONTADOR, 0x10
    BRNE NO_RESET_INC
    CLR CONTADOR

NO_RESET_INC:
    RCALL MOSTRAR_NUM
    RET

; ------------------------------
; Decrementar Contador
; ------------------------------
DECREMENTO:
    RCALL DELAY_ANTIREBOTE
    TST CONTADOR
    BRNE NO_RESET_DEC
    LDI CONTADOR, 0x0F
    RJMP MOSTRAR_NUM

NO_RESET_DEC:
    DEC CONTADOR
    RCALL MOSTRAR_NUM
    RET

; ------------------------------
; Mostrar número en display
; ------------------------------
MOSTRAR_NUM:
    LDI ZH, HIGH(TABLA_SEGMENTOS << 1)
    LDI ZL, LOW(TABLA_SEGMENTOS << 1)
    ADD ZL, CONTADOR
    LPM temp, Z
    OUT PORTD, temp
    RET

; ------------------------------
; Delay antirebote
; ------------------------------
DELAY_ANTIREBOTE:
    LDI r24, 100
L1: LDI r25, 255
L2: DEC r25
    BRNE L2
    DEC r24
    BRNE L1
    RET







