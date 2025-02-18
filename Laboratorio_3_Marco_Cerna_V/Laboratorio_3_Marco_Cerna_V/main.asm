;*****************************************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Laboratorio #3: 
; Created: 17/02/2025 17:02:52
; Author : Marco Cerna V.
;*****************************************************************

.include "m328pdef.inc"

.def temp * R16
.def CONTADOR * R17

.org 0x0000
    RJMP INICIO          
.org PCI0addr           // Dirección de la INterrupción PCINT0 (on-change)
    RJMP ISR_ON_CHANGE  // RutINa de INterrupción 

INICIO:
    LDI temp, 0x0F      
    OUT DDRC, temp
    CLR temp
    OUT PORTC, temp     

    LDI temp, 0x00      
    OUT DDRB, temp						// Configurar PORTB como entrada
    LDI temp, (1 << PB3) | (1 << PB4)	// Activar pull-ups Internos en PB3 y PB4
    OUT PORTB, temp


    LDI temp, (1 << PCIE0)             // Habilitar PCINT en PORTB
    STS PCICR, temp
    LDI temp, (1 << PCINT3) | (1 << PCINT4) // Habilitar Interrupciones en PB3 y PB4
    STS PCMSK0, temp

    LDI CONTADOR, 0x00   
    sei                 // Habilita Interrupciones globales

MAIN_LOOP:
    RJMP MAIN_LOOP      

//*****************************
//  RUTINA DE INTERRUPCIÓN
//*****************************
ISR_ON_CHANGE:
    IN temp, PINB     
    SBRS temp, PB3        // Si PB3 está en bajo (botón incrementar presionado)
    RCALL INCREMENTO     // Llama a incremento
    SBRS temp, PB4      // Si PB4 está en bajo (botón decrementar presionado)
    RCALL DECREMENTO   // Llama a decremento
    RETI              // Sale de la interrupción

//*****************************
// INCREMENTOAR CONTADOR
//*****************************
INCREMENTO:
    RCALL DELAY         // Antirebote
    INC CONTADOR         
    ANDI CONTADOR, 0x0F  // Mantiene el contador en 4 bits (0-15)
    RCALL ACTU_LEDS   // Actualiza los LEDs
    RET

//*****************************
// DECREMENTAR CONTADOR
//*****************************
DECREMENTO:
    RCALL DELAY         // Antirebote
    DEC CONTADOR         
    ANDI CONTADOR, 0x0F  // Mantiene el contador en 4 bits (0-15)
    RCALL ACTU_LEDS   
    RET

//*****************************
// ACTUALIZAR LEDS
//*****************************
ACTU_LEDS:
    MOV temp, CONTADOR
    OUT PORTC, temp     
    RET

//*****************************
// ANTIREBOTE
//*****************************
DELAY:
    LDI r18, 0xFF       
DELAY_LOOP:
    DEC r18
    BRNE DELAY_LOOP
    RET


