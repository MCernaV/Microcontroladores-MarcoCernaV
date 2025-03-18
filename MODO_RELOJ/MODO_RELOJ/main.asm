//MODO RELOJ (ESTADO 0)

.include "m328pdef.inc"

; Definición de pines
.equ DISPLAY_UNIDADES_MIN = PB0
.equ DISPLAY_DECENAS_MIN = PB1
.equ DISPLAY_UNIDADES_HORA = PB2
.equ DISPLAY_DECENAS_HORA = PB3
.equ LED_SEGUNDERO = PC5

.dseg
.org 0x0100
tabla_digitos: .byte 10
contador_unidades_min: .byte 1
contador_decenas_min: .byte 1
contador_unidades_hora: .byte 1
contador_decenas_hora: .byte 1
contador_minutos: .byte 1
contador_horas: .byte 1
contador_segundos: .byte 1
estado_led: .byte 1
contador_parpadeo: .byte 1

.cseg
.org 0x0000
    rjmp RESET
.org OC0Aaddr
    rjmp TIMER0_COMPA

RESET:
    ; Inicialización del stack
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    ; Configuración de puertos
    ldi r16, (1<<DISPLAY_UNIDADES_MIN)|(1<<DISPLAY_DECENAS_MIN)|(1<<DISPLAY_UNIDADES_HORA)|(1<<DISPLAY_DECENAS_HORA)
    out DDRB, r16
    ldi r16, 0b01111111
    out DDRD, r16
    sbi DDRC, LED_SEGUNDERO

    ; Inicialización de variables
    ldi r16, 0
    sts contador_minutos, r16
    sts contador_horas, r16
    sts contador_segundos, r16
    sts estado_led, r16
    sts contador_parpadeo, r16

    ; Inicializar displays
    rcall INICIAR_TABLA_DIGITOS
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    rcall ACTUALIZAR_DISPLAYS_HORAS

    ; Configurar Timer0 en modo CTC
    ldi r16, (1<<WGM01)              ; Modo CTC
    out TCCR0A, r16
    ldi r16, (1<<CS02)|(1<<CS00)     ; Prescaler 1024
    out TCCR0B, r16
    ldi r16, 156                     ; 16MHz/(1024*(156+1)) ? 100Hz
    out OCR0A, r16
    ldi r16, (1<<OCIE0A)             ; Habilitar interrupción por comparación
    sts TIMSK0, r16

    sei

MAIN_LOOP:
    rcall MOSTRAR_RELOJ
    rjmp MAIN_LOOP

INICIAR_TABLA_DIGITOS:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    ldi r16, 0xC0    ; 0
    st Z+, r16
    ldi r16, 0xF9    ; 1
    st Z+, r16
    ldi r16, 0xA4    ; 2
    st Z+, r16
    ldi r16, 0xB0    ; 3
    st Z+, r16
    ldi r16, 0x99    ; 4
    st Z+, r16
    ldi r16, 0x92    ; 5
    st Z+, r16
    ldi r16, 0x82    ; 6
    st Z+, r16
    ldi r16, 0xF8    ; 7
    st Z+, r16
    ldi r16, 0x80    ; 8
    st Z+, r16
    ldi r16, 0x90    ; 9
    st Z+, r16
    ret

TIMER0_COMPA:
    push r16
    in r16, SREG
    push r16

    ; Control del segundero (1Hz)
    lds r16, contador_parpadeo
    inc r16
    cpi r16, 100             ; 100 interrupciones = 1 segundo
    brne NO_SEGUNDO

    ldi r16, 0
    sts contador_parpadeo, r16

    ; Toggle LED
    lds r16, estado_led
    ldi r17, 1
    eor r16, r17
    sts estado_led, r16
    breq APAGAR_LED
    sbi PORTC, LED_SEGUNDERO
    rjmp ACTUALIZAR_TIEMPO

APAGAR_LED:
    cbi PORTC, LED_SEGUNDERO

ACTUALIZAR_TIEMPO:
    lds r16, contador_segundos
    inc r16
    cpi r16, 60
    brne GUARDAR_SEGUNDOS

    ldi r16, 0
    sts contador_segundos, r16
    rcall INCREMENTAR_TIEMPO_AUTO

GUARDAR_SEGUNDOS:
    sts contador_segundos, r16

NO_SEGUNDO:
    sts contador_parpadeo, r16

    pop r16
    out SREG, r16
    pop r16
    reti

MOSTRAR_RELOJ:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    ret

APAGAR_DISPLAYS:
    cbi PORTB, DISPLAY_UNIDADES_MIN
    cbi PORTB, DISPLAY_DECENAS_MIN
    cbi PORTB, DISPLAY_UNIDADES_HORA
    cbi PORTB, DISPLAY_DECENAS_HORA
    ret

MOSTRAR_DIGITO:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    add ZL, r16
    brcc PC+2
    inc ZH
    ld r16, Z
    out PORTD, r16
    ret

DELAY_MULTIPLEX:
    ldi r17, 25
DELAY_LOOP:
    dec r17
    brne DELAY_LOOP
    ret

INCREMENTAR_TIEMPO_AUTO:
    push r16
    lds r16, contador_minutos
    inc r16
    cpi r16, 60
    brne GUARDAR_MINUTO

    ldi r16, 0
    sts contador_minutos, r16
    lds r16, contador_horas
    inc r16
    cpi r16, 24
    brne GUARDAR_HORA
    ldi r16, 0

GUARDAR_HORA:
    sts contador_horas, r16
    rcall ACTUALIZAR_DISPLAYS_HORAS

GUARDAR_MINUTO:
    sts contador_minutos, r16
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    pop r16
    ret

ACTUALIZAR_DISPLAYS_MINUTOS:
    push r16
    push r17
    lds r16, contador_minutos
    ldi r17, 0
DECENAS_MIN:
    cpi r16, 10
    brlo UNIDADES_MIN
    subi r16, 10
    inc r17
    rjmp DECENAS_MIN
UNIDADES_MIN:
    sts contador_unidades_min, r16
    sts contador_decenas_min, r17
    pop r17
    pop r16
    ret

ACTUALIZAR_DISPLAYS_HORAS:
    push r16
    push r17
    lds r16, contador_horas
    ldi r17, 0
DECENAS_HORA:
    cpi r16, 10
    brlo UNIDADES_HORA
    subi r16, 10
    inc r17
    rjmp DECENAS_HORA
UNIDADES_HORA:
    sts contador_unidades_hora, r16
    sts contador_decenas_hora, r17
    pop r17
    pop r16
    ret
