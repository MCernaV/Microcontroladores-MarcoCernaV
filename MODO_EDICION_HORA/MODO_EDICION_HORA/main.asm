.include "m328pdef.inc"

; ===========================================
; Configuración Hardware Modo Horas
; ===========================================
.equ SEGMENTOS_PORT = PORTD    ; PD0-PD6: Segmentos del display
.equ TRANSISTOR_UNI = PB2      ; PB2: Transistor unidades horas
.equ TRANSISTOR_DEC = PB3      ; PB3: Transistor decenas horas
.equ BOTON_UP = PC1            ; PC1: Botón incrementar
.equ BOTON_DOWN = PC2          ; PC2: Botón decrementar

; ===========================================
; Registros y variables
; ===========================================
.def temp = r16
.def horas = r17               ; Valor actual (0-24)
.def unidades = r18            ; Dígito unidades
.def decenas = r19             ; Dígito decenas
.def botones_prev = r20        ; Estado anterior botones
.def display_flag = r21        ; Alternador de displays

.dseg
.org 0x0100
tabla_digitos: .byte 10        ; Tabla conversión 7 segmentos

.cseg
.org 0x0000
    rjmp main
.org OC0Aaddr
    rjmp TIMER0_ISR

; ===========================================
; Programa principal
; ===========================================
main:
    ; Inicialización del stack
    ldi temp, HIGH(RAMEND)
    out SPH, temp
    ldi temp, LOW(RAMEND)
    out SPL, temp

    ; Configurar puertos
    ldi temp, (1<<TRANSISTOR_UNI)|(1<<TRANSISTOR_DEC)
    out DDRB, temp
    ldi temp, 0b01111111       ; PD0-PD6 como salidas
    out DDRD, temp
    ldi temp, (1<<BOTON_UP)|(1<<BOTON_DOWN)
    out PORTC, temp            ; Pull-ups en botones

    ; Inicializar variables
    clr horas
    clr botones_prev
    clr display_flag
    rcall actualizar_display

    ; Configurar Timer0 (250Hz para multiplexado)
    ldi temp, 64              ; 16MHz/1024/64 ? 244Hz
    out OCR0A, temp
    ldi temp, (1<<WGM01)      ; Modo CTC
    out TCCR0A, temp
    ldi temp, (1<<CS02)|(1<<CS00) ; Prescaler 1024
    out TCCR0B, temp
    ldi temp, (1<<OCIE0A)     ; Habilitar interrupción
    sts TIMSK0, temp

    ; Inicializar tabla 7 segmentos (misma configuración)
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

; ===========================================
; Interrupción Timer0 (Multiplexado)
; ===========================================
TIMER0_ISR:
    push temp
    in temp, SREG
    push temp

    rcall multiplexar_displays

    pop temp
    out SREG, temp
    pop temp
    reti

; ===========================================
; Multiplexado de displays para horas
; ===========================================
multiplexar_displays:
    sbrs display_flag, 0
    rjmp mostrar_decenas_horas

mostrar_unidades_horas:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    add ZL, unidades
    ld temp, Z
    out SEGMENTOS_PORT, temp
    cbi PORTB, TRANSISTOR_DEC     ; Apagar decenas
    sbi PORTB, TRANSISTOR_UNI     ; Encender unidades
    ldi display_flag, 0
    ret

mostrar_decenas_horas:
    ldi ZH, HIGH(tabla_digitos)
    ldi ZL, LOW(tabla_digitos)
    add ZL, decenas
    ld temp, Z
    out SEGMENTOS_PORT, temp
    cbi PORTB, TRANSISTOR_UNI     ; Apagar unidades
    sbi PORTB, TRANSISTOR_DEC     ; Encender decenas
    ldi display_flag, 1
    ret

; ===========================================
; Lógica de actualización de display
; ===========================================
actualizar_display:
    mov temp, horas
    ldi decenas, 0
calcular_decenas_horas:
    cpi temp, 10
    brlo fin_calculo_horas
    subi temp, 10
    inc decenas
    rjmp calcular_decenas_horas
fin_calculo_horas:
    mov unidades, temp
    ret

; ===========================================
; Lectura de botones (Misma implementación)
; ===========================================
leer_botones:
    in temp, PINC
    com temp                 ; Invertir lógica (0 = presionado)
    andi temp, (1<<BOTON_UP)|(1<<BOTON_DOWN)
    mov r22, temp

    ; Detectar flancos de bajada
    eor r22, botones_prev
    and r22, temp
    mov botones_prev, temp

    ; Procesar botones
    sbrc r22, BOTON_UP
    rcall incrementar_horas
    sbrc r22, BOTON_DOWN
    rcall decrementar_horas

    ret

; ===========================================
; Lógica de incremento/decremento para horas
; ===========================================
incrementar_horas:
    inc horas
    cpi horas, 24
    brlo fin_incremento_horas
    clr horas                ; Reiniciar a 00 al llegar a 24
fin_incremento_horas:
    rcall actualizar_display
    ret

decrementar_horas:
    dec horas
    cpi horas, 0xFF          ; Verificar underflow
    brne fin_decremento_horas
    ldi horas, 24            ; Reiniciar a 24 al pasar de 00
fin_decremento_horas:
    rcall actualizar_display
    ret