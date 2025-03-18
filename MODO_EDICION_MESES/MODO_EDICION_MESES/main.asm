.include "m328pdef.inc"

; ===========================================
; Configuración Hardware Modo Meses
; ===========================================
.equ SEGMENTOS_PORT = PORTD    ; PD0-PD6: Segmentos
.equ TRANSISTOR_UNI = PB2      ; PB2: Unidades
.equ TRANSISTOR_DEC = PB3      ; PB3: Decenas
.equ BOTON_UP = PC1            ; PC1: Incrementar
.equ BOTON_DOWN = PC2          ; PC2: Decrementar

; ===========================================
; Registros y variables
; ===========================================
.def temp = r16
.def meses = r17               ; Valor actual (1-12)
.def unidades = r18
.def decenas = r19
.def botones_prev = r20
.def display_flag = r21

.dseg
.org 0x0100
tabla_digitos: .byte 10

.cseg
.org 0x0000
    rjmp main
.org OC0Aaddr
    rjmp TIMER0_ISR

main:
    ; Inicialización del stack
    ldi temp, HIGH(RAMEND)
    out SPH, temp
    ldi temp, LOW(RAMEND)
    out SPL, temp

    ; Configurar puertos
    ldi temp, (1<<TRANSISTOR_UNI)|(1<<TRANSISTOR_DEC)
    out DDRB, temp
    ldi temp, 0b01111111
    out DDRD, temp
    ldi temp, (1<<BOTON_UP)|(1<<BOTON_DOWN)
    out PORTC, temp

    ; Inicializar variables
    ldi meses, 1               ; Iniciar en 01 (Enero)
    clr botones_prev
    clr display_flag
    rcall actualizar_display

    ; Inicializar Timer0 (250Hz)
    ldi temp, 64
    out OCR0A, temp
    ldi temp, (1<<WGM01)
    out TCCR0A, temp
    ldi temp, (1<<CS02)|(1<<CS00)
    out TCCR0B, temp
    ldi temp, (1<<OCIE0A)
    sts TIMSK0, temp

    ; Inicializar tabla 7 segmentos
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    ldi temp, 0xC0 ; 0
    st Z+, temp
    ldi temp, 0xF9 ; 1
    st Z+, temp
    ldi temp, 0xA4 ; 2
    st Z+, temp
    ldi temp, 0xB0 ; 3
    st Z+, temp
    ldi temp, 0x99 ; 4
    st Z+, temp
    ldi temp, 0x92 ; 5
    st Z+, temp
    ldi temp, 0x82 ; 6
    st Z+, temp
    ldi temp, 0xF8 ; 7
    st Z+, temp
    ldi temp, 0x80 ; 8
    st Z+, temp
    ldi temp, 0x90 ; 9
    st Z+, temp

    sei

loop:
    rcall leer_botones
    rjmp loop

TIMER0_ISR:
    push temp
    in temp, SREG
    push temp
    rcall multiplexar_displays
    pop temp
    out SREG, temp
    pop temp
    reti

multiplexar_displays:
    sbrs display_flag, 0
    rjmp mostrar_decenas_mes
mostrar_unidades_mes:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    add ZL, unidades
    ld temp, Z
    out SEGMENTOS_PORT, temp
    cbi PORTB, TRANSISTOR_DEC
    sbi PORTB, TRANSISTOR_UNI
    ldi display_flag, 0
    ret
mostrar_decenas_mes:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    add ZL, decenas
    ld temp, Z
    out SEGMENTOS_PORT, temp
    cbi PORTB, TRANSISTOR_UNI
    sbi PORTB, TRANSISTOR_DEC
    ldi display_flag, 1
    ret

actualizar_display:
    mov temp, meses
    ldi decenas, 0
calcular_decenas_mes:
    cpi temp, 10
    brlo fin_calculo_mes
    subi temp, 10
    inc decenas
    rjmp calcular_decenas_mes
fin_calculo_mes:
    mov unidades, temp
    ret

leer_botones:
    in temp, PINC
    com temp
    andi temp, (1<<BOTON_UP)|(1<<BOTON_DOWN)
    mov r22, temp
    eor r22, botones_prev
    and r22, temp
    mov botones_prev, temp
    sbrc r22, BOTON_UP
    rcall incrementar_mes
    sbrc r22, BOTON_DOWN
    rcall decrementar_mes
    ret

incrementar_mes:
    inc meses
    cpi meses, 13
    brlo fin_incremento_mes
    ldi meses, 1
fin_incremento_mes:
    rcall actualizar_display
    ret

decrementar_mes:
    dec meses
    cpi meses, 0
    brne fin_decremento_mes
    ldi meses, 12
fin_decremento_mes:
    rcall actualizar_display
    ret