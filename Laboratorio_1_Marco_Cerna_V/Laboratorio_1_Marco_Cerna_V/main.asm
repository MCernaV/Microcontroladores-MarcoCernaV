//*****************************************************************
// Universidad del Valle de Guatemala
// IE2023: Programacion de microcontroladores
// Proyecto: Lab 1: Sumador de 4 bits
// Created: 30/1/2025 18:40:44
// Author : Marco Cerna V.
//Descripción: En este programa se llevaron a cabo un sumador de 4 bits
//*****************************************************************

.INCLUDE "M328PDEF.inc"

.CSEG
.ORG 0x00        
RJMP MAIN    

;=============================
; Configuración del Stack Pointer
;=============================
MAIN:
    LDI R16, LOW(RAMEND)
    OUT SPL, R16  

;=============================
; Configuración de Puertos
;=============================
Setup:
    ;Primer contador:

    LDI R16, 0b00001111  ; PB0-PB3 como salida (LEDs 1er contador)
    OUT DDRB, R16  
    LDI R16, 0b11110110  ; PC3 y PC0 como entrada (REV_BOTONES 1er contador)
    OUT DDRC, R16  

    ;Segundo contador:
    LDI R16, 0b11110000  ; PD4-PD7 como salida (LEDs 2do contador)
    OUT DDRD, R16  
    LDI R16, 0b11111001  ; PC1 y PC2 como entrada (REV_BOTONES 2do contador)
    OUT DDRC, R16  

    ;Resultado de la Suma:
    LDI R16, 0b00001111  ; PD0-PD3 como salida (LEDs resultado)
    OUT DDRD, R16  
    LDI R16, 0b11101111  ; PC4 como entrada (Botón de suma)
    OUT DDRC, R16  

    ;LED Carry:
    LDI R16, 0b00010000  ; PB4 como salida (Carry)
    OUT DDRB, R16  

    ;Inicializar registros de contadores
    CLR R19  ; Guarda Contador 1
    CLR R17  ; Guarda Contador 2
    CLR R18  ; Guarda Suma

    ;Apagar LEDS
    OUT PORTB, R19  
    OUT PORTD, R17  
    OUT PORTD, R18  
    CBI PORTB, PB4

;=============================
; Bucle Principal
;=============================
LOOP:
    CALL REV_BOTONES
    OUT PORTB, R19  ; Mostrar contador 1 
    OUT PORTD, R17  ;Mostrar contador 2
    RJMP LOOP  

;=============================
; Subrutina para verificar REV_BOTONES con antirebote
;=============================
REV_BOTONES:
    SBIC PINC, 3   ; Si PC3 (incremento contador 1) está presionado
    CALL INCREMENTO1
    SBIC PINC, 0   ; Si PC0 (decremento contador 1) está presionado
    CALL DECREMENTO1
    SBIC PINC, 1   ; Si PC1 (incremento contador 2) está presionado
    CALL INCREMENTO2
    SBIC PINC, 2   ; Si PC2 (decremento contador 2) está presionado
    CALL DECREMENTO2
    SBIC PINC, 4   ; Si PC4 (botón de suma) está presionado
    CALL SUMA
    RET

;=============================
; Subrutinas para los contadores
;=============================
INCREMENTO1:
    INC R19          
    CPI R19, 16     ; Si R19 == 16 (overflow de 4 bits)
    BREQ RESEST_CONTADOR1  
    CALL ANTIREBOTE
    RET

DECREMENTO1:
    CPI R19, 0      ; Si el contador es 0, no decrementar
    BREQ NO_DECREMENTO1
    DEC R19
NO_DECREMENTO1:
    CALL ANTIREBOTE
    RET

INCREMENTO2:
    INC R17          
    CPI R17, 16     ; Si R17 == 16 (overflow de 4 bits)
    BREQ RESET_CONTADOR2  
    CALL ANTIREBOTE
    RET

DECREMENTO2:
    CPI R17, 0      ; Si el contador es 0, no decrementar
    BREQ NO_DECREMENTO2
    DEC R17
NO_DECREMENTO2:
    CALL ANTIREBOTE
    RET

RESEST_CONTADOR1:
    CLR R19  
    RET

RESET_CONTADOR2:
    CLR R17  
    RET

;=============================
; Subrutina para calcular la suma
;=============================
SUMA:
    MOV R18, R19   
    ADD R18, R17    

    CPI R18, 16     ; Si la suma supera 15, hay carry
    BRLO NO_CARRY
    SBI PORTB, 4    ; Enciende el LED de carry en PB4
    ANDI R18, 0x0F  ; Limita a 4 bits
    RJMP MOSTRAR_SUMA

NO_CARRY:
    CBI PORTB, 4    ; Apaga el LED de carry en PB4

MOSTRAR_SUMA:
    OUT PORTD, R18 
    CALL ANTIREBOTE
    RET

;=============================
; Subrutina de antirebote
;=============================
ANTIREBOTE:
    LDI R20, 100  
DELAY_LOOP:
    DEC R20
    BRNE DELAY_LOOP
    RET
