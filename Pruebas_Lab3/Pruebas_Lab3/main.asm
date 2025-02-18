.include "m328pdef.inc"

.def temp = r16
.def counter = r17

.org 0x0000
    rjmp START          
.org PCI0addr           ; Direcci�n de la interrupci�n PCINT0 (on-change)
    rjmp ISR_ON_CHANGE  ; Rutina de interrupci�n 

START:
    ldi temp, 0x0F      
    out DDRC, temp
    clr temp
    out PORTC, temp     

    ldi temp, 0x00      
    out DDRB, temp						// Configurar PORTB como entrada
    ldi temp, (1 << PB3) | (1 << PB4)	// Activar pull-ups internos en PB3 y PB4
    out PORTB, temp


    ldi temp, (1 << PCIE0)             // Habilitar PCINT en PORTB
    sts PCICR, temp
    ldi temp, (1 << PCINT3) | (1 << PCINT4) // Habilitar interrupciones en PB3 y PB4
    sts PCMSK0, temp

    ldi counter, 0x00   
    sei                 ; Habilita interrupciones globales

MAIN_LOOP:
    rjmp MAIN_LOOP      

;=============================
;  RUTINA DE INTERRUPCI�N
;=============================
ISR_ON_CHANGE:
    in temp, PINB       ; Leer estado actual de PORTB
    sbrs temp, PB3      ; Si PB3 est� en bajo (bot�n incrementar presionado)
    rcall INCREMENT     ; Llama a la rutina de incremento
    sbrs temp, PB4      ; Si PB4 est� en bajo (bot�n decrementar presionado)
    rcall DECREMENT     ; Llama a la rutina de decremento
    reti                ; Retorna de la interrupci�n

;=============================
;  FUNCI�N: INCREMENTAR CONTADOR
;=============================
INCREMENT:
    rcall DELAY         ; Antirebote
    inc counter         ; Incrementa el contador
    andi counter, 0x0F  ; Mantiene el contador en 4 bits (0-15)
    rcall UPDATE_LEDS   ; Actualiza los LEDs
    ret

;=============================
;  FUNCI�N: DECREMENTAR CONTADOR
;=============================
DECREMENT:
    rcall DELAY         ; Antirebote
    dec counter         ; Decrementa el contador
    andi counter, 0x0F  ; Mantiene el contador en 4 bits (0-15)
    rcall UPDATE_LEDS   ; Actualiza los LEDs
    ret

;=============================
;  FUNCI�N: ACTUALIZAR LEDs
;=============================
UPDATE_LEDS:
    mov temp, counter
    out PORTC, temp     ; Muestra el valor del contador en los LEDs
    ret

;=============================
;  FUNCI�N: ANTI-REBOTE
;=============================
DELAY:
    ldi r18, 0xFF       ; Retardo simple
DELAY_LOOP:
    dec r18
    brne DELAY_LOOP
    ret


