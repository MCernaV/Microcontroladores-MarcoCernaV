.include "m328pdef.inc"

; ===========================================
; Configuración Hardware
; ===========================================
.equ SEGMENTOS_PORT = PORTD    ; PD0-PD6: Segmentos
.equ TRANSISTOR_MES_UNI = PB2  ; PB2: Unidades meses
.equ TRANSISTOR_MES_DEC = PB3  ; PB3: Decenas meses
.equ TRANSISTOR_DIA_UNI = PB0  ; PB0: Unidades días
.equ TRANSISTOR_DIA_DEC = PB1  ; PB1: Decenas días
.equ BOTON_MODO = PC0          ; PC0: Cambio modo Mes/Día
.equ BOTON_UP = PC1            ; PC1: Incrementar
.equ BOTON_DOWN = PC2          ; PC2: Decrementar
.equ SEGUNDERO = PC5           ; PC5: LED segundero

; ===========================================
; Variables en SRAM
; ===========================================
.dseg
.org 0x0100
    mes:          .byte 1
    dia:          .byte 1
    display_flag: .byte 1
    contador_seg: .byte 1
    unidades:     .byte 1
    decenas:      .byte 1
    botones_prev: .byte 1
    modo:         .byte 1
    tabla_digitos: .byte 10

.cseg
.org 0x0000
    rjmp main
.org OC0Aaddr
    rjmp TIMER0_ISR

tabla_max_dias: .db 31,28,31,30,31,30,31,31,30,31,30,31

main:
    ; Inicialización del stack
    ldi r16, HIGH(RAMEND)
    out SPH, r16
    ldi r16, LOW(RAMEND)
    out SPL, r16

    ; Configurar puertos
    ldi r16, (1<<TRANSISTOR_MES_UNI)|(1<<TRANSISTOR_MES_DEC)|(1<<TRANSISTOR_DIA_UNI)|(1<<TRANSISTOR_DIA_DEC)
    out DDRB, r16
    ldi r16, 0b01111111
    out DDRD, r16
    sbi DDRC, SEGUNDERO
    ldi r16, (1<<BOTON_MODO)|(1<<BOTON_UP)|(1<<BOTON_DOWN)
    out PORTC, r16

    ; Inicializar variables en SRAM
    ldi r16, 1
    sts mes, r16
    sts dia, r16
    clr r16
    sts display_flag, r16
    sts contador_seg, r16
    sts botones_prev, r16
    sts modo, r16

    ; Inicializar tabla 7 segmentos
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    ldi r16, 0xC0 ; 0
    st Z+, r16
    ldi r16, 0xF9 ; 1
    st Z+, r16
    ldi r16, 0xA4 ; 2
    st Z+, r16
    ldi r16, 0xB0 ; 3
    st Z+, r16
    ldi r16, 0x99 ; 4
    st Z+, r16
    ldi r16, 0x92 ; 5
    st Z+, r16
    ldi r16, 0x82 ; 6
    st Z+, r16
    ldi r16, 0xF8 ; 7
    st Z+, r16
    ldi r16, 0x80 ; 8
    st Z+, r16
    ldi r16, 0x90 ; 9
    st Z+, r16

    ; Configurar Timer0
    ldi r16, 64
    out OCR0A, r16
    ldi r16, (1<<WGM01)
    out TCCR0A, r16
    ldi r16, (1<<CS02)|(1<<CS00)
    out TCCR0B, r16
    ldi r16, (1<<OCIE0A)
    sts TIMSK0, r16

    sei

loop:
    rcall leer_botones
    rjmp loop

; ===========================================
; Interrupción Timer0
; ===========================================
TIMER0_ISR:
    push r16
    in r16, SREG
    push r16

    rcall multiplexar_displays
    rcall actualizar_segundero

    pop r16
    out SREG, r16
    pop r16
    reti

; ===========================================
; Funciones optimizadas
; ===========================================
actualizar_segundero:
    lds r16, contador_seg
    inc r16
    cpi r16, 250
    brne fin_segundero
    clr r16
    sbi PINC, SEGUNDERO
fin_segundero:
    sts contador_seg, r16
    ret

multiplexar_displays:
    lds r16, modo
    sbrc r16, 0
    rjmp modo_dia

modo_mes:
    lds r16, display_flag
    sbrc r16, 0
    rjmp mostrar_decenas_mes

mostrar_unidades_mes:
    lds ZL, unidades
    ldi ZH, HIGH(tabla_digitos)
    add ZL, LOW(tabla_digitos)
    ld r16, Z
    out SEGMENTOS_PORT, r16
    cbi PORTB, TRANSISTOR_MES_DEC
    sbi PORTB, TRANSISTOR_MES_UNI
    ldi r16, 1
    sts display_flag, r16
    ret

mostrar_decenas_mes:
    lds ZL, decenas
    ldi ZH, HIGH(tabla_digitos)
    add ZL, LOW(tabla_digitos)
    ld r16, Z
    out SEGMENTOS_PORT, r16
    cbi PORTB, TRANSISTOR_MES_UNI
    sbi PORTB, TRANSISTOR_MES_DEC
    clr r16
    sts display_flag, r16
    ret

modo_dia:
    lds r16, display_flag
    sbrc r16, 0
    rjmp mostrar_decenas_dia

mostrar_unidades_dia:
    lds ZL, unidades
    ldi ZH, HIGH(tabla_digitos)
    add ZL, LOW(tabla_digitos)
    ld r16, Z
    out SEGMENTOS_PORT, r16
    cbi PORTB, TRANSISTOR_DIA_DEC
    sbi PORTB, TRANSISTOR_DIA_UNI
    ldi r16, 1
    sts display_flag, r16
    ret

mostrar_decenas_dia:
    lds ZL, decenas
    ldi ZH, HIGH(tabla_digitos)
    add ZL, LOW(tabla_digitos)
    ld r16, Z
    out SEGMENTOS_PORT, r16
    cbi PORTB, TRANSISTOR_DIA_UNI
    sbi PORTB, TRANSISTOR_DIA_DEC
    clr r16
    sts display_flag, r16
    ret

; ===========================================
; Lógica común para conversión decimal
; ===========================================
convertir_decimal:
    ldi r17, 0
calcular_decenas:
    cpi r16, 10
    brlo fin_conversion
    subi r16, 10
    inc r17
    rjmp calcular_decenas
fin_conversion:
    sts decenas, r17
    sts unidades, r16
    ret

; ===========================================
; Lógica de botones optimizada
; ===========================================
leer_botones:
    in r16, PINC
    com r16
    andi r16, (1<<BOTON_MODO)|(1<<BOTON_UP)|(1<<BOTON_DOWN)
    lds r17, botones_prev
    mov r18, r16
    eor r18, r17
    and r18, r16
    sts botones_prev, r16

    sbrc r18, BOTON_MODO
    rcall cambiar_modo

    lds r16, modo
    sbrc r16, 0
    rjmp procesar_dia

procesar_mes:
    sbrc r18, BOTON_UP
    rcall incrementar_mes
    sbrc r18, BOTON_DOWN
    rcall decrementar_mes
    ret

procesar_dia:
    sbrc r18, BOTON_UP
    rcall incrementar_dia
    sbrc r18, BOTON_DOWN
    rcall decrementar_dia
    ret

; ===========================================
; Funciones unificadas de ajuste
; ===========================================
ajustar_mes:
    lds r16, mes
    sbrc r18, BOTON_UP
    inc r16
    sbrc r18, BOTON_DOWN
    dec r16
    cpi r16, 13
    brlo validar_mes
    ldi r16, 1
validar_mes:
    cpi r16, 0
    brne guardar_mes
    ldi r16, 12
guardar_mes:
    sts mes, r16
    rcall actualizar_display_mes
    ret

ajustar_dia:
    lds r16, dia
    sbrc r18, BOTON_UP
    inc r16
    sbrc r18, BOTON_DOWN
    dec r16
    rcall limitar_dia
    sts dia, r16
    rcall actualizar_display_dia
    ret

actualizar_display_mes:
    lds r16, mes
    rcall convertir_decimal
    ret

actualizar_display_dia:
    lds r16, dia
    rcall convertir_decimal
    ret

limitar_dia:
    push ZH
    push ZL
    ldi ZH, HIGH(tabla_max_dias*2)
    ldi ZL, LOW(tabla_max_dias*2)
    lds r17, mes
    dec r17
    add ZL, r17
    clr r1
    adc ZH, r1
    lpm r17, Z
    pop ZL
    pop ZH

    cp r16, r17
    brlo dia_valido
    mov r16, r17
dia_valido:
    cpi r16, 1
    brsh fin_limite
    mov r16, r17
fin_limite:
    ret

cambiar_modo:
    lds r16, modo
    ldi r17, 1
    eor r16, r17
    sts modo, r16
    ret
