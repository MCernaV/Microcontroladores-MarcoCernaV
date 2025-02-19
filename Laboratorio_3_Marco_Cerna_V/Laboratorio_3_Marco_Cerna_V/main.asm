;*****************************************************************
; Universidad del Valle de Guatemala
; IE2023: Programación de Microcontroladores
; Laboratorio #3: 
; Created: 17/02/2025 17:02:52
; Author : Marco Cerna V.
;*****************************************************************


.include "m328Pdef.inc"

.org 0x0000
    rjmp RESET              
//.org OC0Aaddr
    rjmp TIMER0_COMPA_ISR   ; Vector de interrupción para Timer0 Compare Match A
.org PCI0addr           // Dirección de la Interrupción PCINT0 (on-change)
    RJMP ISR_ON_CHANGE  // Rutina de Interrupción 


;--------------------------------------
; Definición de registros utilizados
.def DISPLAY   = r16         ; Variable que almacena el dígito actual (0-9)
.def CONTADOR = r17         ; Contador de interrupciones (~16 ms cada una)
.def temp    = r18  
.def CONTADOR2 = r19    

;--------------------------------------
; Rutina de reset

RESET:
    ; Inicializa el Stack Pointer
    ldi r16, low(RAMEND)
    out SPL, r16
    ldi r16, high(RAMEND)
    out SPH, r16

    ldi temp, 0xFF         
    out DDRD, temp

	ldi temp, 0xFF         
    out DDRC, temp

    ; Inicializa el display en 0
    LDI DISPLAY, 0
    RCALL DISPLAY_ACTU

    LDI temp, 0x00      
    OUT DDRB, temp						// Configurar PORTB como entrada
    LDI temp, (1 << PB3) | (1 << PB4)	// Activar pull-ups Internos en PB3 y PB4
    OUT PORTB, temp

    LDI temp, (1 << PCIE0)             // Habilitar PCINT en PORTB
    STS PCICR, temp
    LDI temp, (1 << PCINT3) | (1 << PCINT4) // Habilitar Interrupciones en PB3 y PB4
    STS PCMSK0, temp

    LDI CONTADOR2, 0x00   


   /* LDI temp, (1<<WGM01)   // Setear el Timer 0 en modo CTC 
	OUT TCCR0A, temp

    LDI	 temp, (1<<CS02)|(1<<CS00) 
    OUT TCCR0B, temp

    LDI temp, 100         
    OUT OCR0A, temp

    LDI temp, (1<<OCIE0A)
    STS TIMSK0, temp */

    ; Habilita interrupciones globales
    SEI

MAIN_LOOP:
    rjmp MAIN_LOOP          

ISR_ON_CHANGE:
    IN temp, PINB     
    SBRS temp, PB3        // Si PB3 está en bajo (botón incrementar presionado)
    RCALL INCREMENTO     // Llama a incremento
    SBRS temp, PB4      // Si PB4 está en bajo (botón decrementar presionado)
    RCALL DECREMENTO   // Llama a decremento
    RETI              // Sale de la interrupción

//*****************************
// INCREMENTAR CONTADOR
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

TIMER0_COMPA_ISR:

    INC CONTADOR             
    CPI CONTADOR, 100         
    BRNE SALIR
	//Si llega a 10 
    LDI CONTADOR, 0
    INC DISPLAY               ; Incrementa el dígito
    CPI DISPLAY, 10
    BRLO NO_RESET
    LDI DISPLAY, 0            ; Vuelve a 0 al llegar a 10
NO_RESET:
    RCALL DISPLAY_ACTU    ; Actualiza el display

SALIR: 
    RETI

DISPLAY_ACTU:
    CPI DISPLAY, 0
    BREQ CERO
    CPI DISPLAY, 1
    BREQ UNO
    CPI DISPLAY, 2
    BREQ DOS
    CPI DISPLAY, 3
    BREQ TRES
    CPI DISPLAY, 4
    BREQ CUATRO
    CPI DISPLAY, 5
    BREQ CINCO
    CPI DISPLAY, 6
    BREQ SEIS
    CPI DISPLAY, 7
    BREQ SIETE
    CPI DISPLAY, 8
    BREQ OCHO
    CPI DISPLAY, 9
    BREQ NUEVE

CERO:   
ldi temp, 0x3F  
rjmp DISP_OUT

UNO:    
ldi temp, 0x06  
rjmp DISP_OUT

DOS:    
ldi temp, 0x5B 
rjmp DISP_OUT

TRES:  
ldi temp, 0x4F 
rjmp DISP_OUT

CUATRO:   
ldi temp, 0x66  
rjmp DISP_OUT

CINCO:   
ldi temp, 0x6D  
rjmp DISP_OUT

SEIS:    
ldi temp, 0x7D  
rjmp DISP_OUT

SIETE:  
ldi temp, 0x07  
rjmp DISP_OUT

OCHO:  
ldi temp, 0x7F  
rjmp DISP_OUT

NUEVE:   
ldi temp, 0x6F  

DISP_OUT:
    out PORTD, temp      
    ret







