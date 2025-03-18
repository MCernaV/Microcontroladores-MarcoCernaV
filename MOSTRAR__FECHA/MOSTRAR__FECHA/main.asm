//MODO FECHA (ESTADO 3)

.include "m328pdef.inc"

; Definición de pines
.equ DISPLAY_UNIDADES_DIA = PB0
.equ DISPLAY_DECENAS_DIA = PB1
.equ DISPLAY_UNIDADES_MES = PB2
.equ DISPLAY_DECENAS_MES = PB3
.equ LED_INDICADOR = PC5

.dseg
.org 0x0100
tabla_digitos: .byte 10
contador_unidades_dia: .byte 1
contador_decenas_dia: .byte 1
contador_unidades_mes: .byte 1
contador_decenas_mes: .byte 1
contador_dia: .byte 1
contador_mes: .byte 1
estado_led: .byte 1
contador_parpadeo: .byte 1
estado_actual: .byte 1
dias_por_mes: .byte 12  ; Almacena días por mes (31,28/29,31,30,31,30,31,31,30,31,30,31)
anio_actual: .byte 1     ; 0-99 para años

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
    ldi r16, (1<<DISPLAY_UNIDADES_DIA)|(1<<DISPLAY_DECENAS_DIA)|(1<<DISPLAY_UNIDADES_MES)|(1<<DISPLAY_DECENAS_MES)
    out DDRB, r16
    ldi r16, 0b01111111
    out DDRD, r16
    sbi DDRC, LED_INDICADOR

    ; Inicialización de variables
    ldi r16, 1       ; Fecha inicial: 01/01
    sts contador_dia, r16
    sts contador_mes, r16
    ldi r16, 24      ; Año inicial: 2024
    sts anio_actual, r16
    ldi r16, 0
    sts estado_led, r16
    sts contador_parpadeo, r16
    ldi r16, 3       ; Estado 3 (modo fecha)
    sts estado_actual, r16

    ; Inicializar tabla de días por mes
    rcall INICIAR_TABLA_DIAS_MES
    
    ; Inicializar displays
    rcall INICIAR_TABLA_DIGITOS
    rcall ACTUALIZAR_DISPLAYS_DIA
    rcall ACTUALIZAR_DISPLAYS_MES

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

MAIN_LOOP_FECHA:
    rcall MOSTRAR_FECHA
    rjmp MAIN_LOOP_FECHA

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

INICIAR_TABLA_DIAS_MES:
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    ldi r16, 31    ; Enero
    st Z+, r16
    
    ; Comprobar si es año bisiesto
    lds r16, anio_actual
    andi r16, 0x03   ; r16 & 0x03 (resto de dividir por 4)
    brne NO_BISIESTO
    ldi r16, 29      ; Febrero (bisiesto)
    rjmp GUARDAR_FEBRERO
NO_BISIESTO:
    ldi r16, 28      ; Febrero (no bisiesto)
GUARDAR_FEBRERO:
    st Z+, r16
    
    ldi r16, 31    ; Marzo
    st Z+, r16
    ldi r16, 30    ; Abril
    st Z+, r16
    ldi r16, 31    ; Mayo
    st Z+, r16
    ldi r16, 30    ; Junio
    st Z+, r16
    ldi r16, 31    ; Julio
    st Z+, r16
    ldi r16, 31    ; Agosto
    st Z+, r16
    ldi r16, 30    ; Septiembre
    st Z+, r16
    ldi r16, 31    ; Octubre
    st Z+, r16
    ldi r16, 30    ; Noviembre
    st Z+, r16
    ldi r16, 31    ; Diciembre
    st Z+, r16
    ret

TIMER0_COMPA:
    push r16
    push r17
    in r16, SREG
    push r16

    ; Control del parpadeo del LED (1Hz)
    lds r16, contador_parpadeo
    inc r16
    cpi r16, 100             ; 100 interrupciones = 1 segundo
    brne NO_SEGUNDO_FECHA

    ldi r16, 0
    sts contador_parpadeo, r16

    ; Toggle LED
    lds r16, estado_led
    ldi r17, 1
    eor r16, r17
    sts estado_led, r16
    breq APAGAR_LED_FECHA
    sbi PORTC, LED_INDICADOR
    rjmp FIN_LED_FECHA

APAGAR_LED_FECHA:
    cbi PORTC, LED_INDICADOR

FIN_LED_FECHA:
    ; No actualizamos la fecha automáticamente, solo el parpadeo del LED

NO_SEGUNDO_FECHA:
    sts contador_parpadeo, r16

    pop r16
    out SREG, r16
    pop r17
    pop r16
    reti

MOSTRAR_FECHA:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_DIA
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_DIA
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MES
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MES
    rcall DELAY_MULTIPLEX
    ret

APAGAR_DISPLAYS:
    cbi PORTB, DISPLAY_UNIDADES_DIA
    cbi PORTB, DISPLAY_DECENAS_DIA
    cbi PORTB, DISPLAY_UNIDADES_MES
    cbi PORTB, DISPLAY_DECENAS_MES
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
DELAY_LOOP_FECHA:
    dec r17
    brne DELAY_LOOP_FECHA
    ret

; Función para incrementar la fecha manualmente (botón)
INCREMENTAR_DIA:
    push r16
    push r17
    push r18
    
    ; Obtenemos el número de días del mes actual
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    lds r18, contador_mes
    dec r18          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r18
    brcc PC+2
    inc ZH
    ld r17, Z        ; r17 contiene el número de días del mes actual
    
    ; Incrementamos el día
    lds r16, contador_dia
    inc r16
    cp r16, r17
    brlt GUARDAR_DIA_INC   ; Si día < días del mes, guardamos
    breq GUARDAR_DIA_INC   ; Si día = días del mes, todavía guardamos
    
    ldi r16, 1       ; Día = 1, pasamos al siguiente mes
    sts contador_dia, r16
    
    lds r16, contador_mes
    inc r16
    cpi r16, 13
    brne GUARDAR_MES_INC
    
    ldi r16, 1       ; Si mes > 12, mes = 1 y incrementamos año
    
    ; Incrementar año y recalcular días de febrero por bisiesto
    lds r18, anio_actual
    inc r18
    cpi r18, 100
    brne GUARDAR_ANIO_INC
    ldi r18, 0       ; Si año = 100, año = 0
GUARDAR_ANIO_INC:
    sts anio_actual, r18
    rcall INICIAR_TABLA_DIAS_MES    ; Actualizar días por mes (por si cambió febrero)
    
GUARDAR_MES_INC:
    sts contador_mes, r16
    rcall ACTUALIZAR_DISPLAYS_MES
    rjmp ACTUALIZAR_DISPLAYS_FECHA
    
GUARDAR_DIA_INC:
    sts contador_dia, r16
    
ACTUALIZAR_DISPLAYS_FECHA:
    rcall ACTUALIZAR_DISPLAYS_DIA
    pop r18
    pop r17
    pop r16
    ret

; Función para incrementar el mes manualmente (botón)
INCREMENTAR_MES:
    push r16
    push r17
    push r18
    
    ; Incrementamos el mes
    lds r16, contador_mes
    inc r16
    cpi r16, 13
    brne GUARDAR_MES_DIRECTO
    
    ldi r16, 1       ; Si mes > 12, mes = 1
    
GUARDAR_MES_DIRECTO:
    sts contador_mes, r16
    rcall ACTUALIZAR_DISPLAYS_MES
    
    ; Verificar que el día actual no exceda el máximo del nuevo mes
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    dec r16          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r16
    brcc PC+2
    inc ZH
    ld r17, Z        ; r17 contiene el número de días del mes actual
    
    lds r16, contador_dia
    cp r16, r17
    brlt FINALIZAR_AJUSTE_DIA    ; Si día < días del mes, no ajustamos
    breq FINALIZAR_AJUSTE_DIA    ; Si día = días del mes, tampoco ajustamos
    
    mov r16, r17     ; Si día > días del mes, día = días del mes
    sts contador_dia, r16
    rcall ACTUALIZAR_DISPLAYS_DIA
    
FINALIZAR_AJUSTE_DIA:
    pop r18
    pop r17
    pop r16
    ret

ACTUALIZAR_DISPLAYS_DIA:
    push r16
    push r17
    lds r16, contador_dia
    ldi r17, 0
DECENAS_DIA:
    cpi r16, 10
    brlo UNIDADES_DIA
    subi r16, 10
    inc r17
    rjmp DECENAS_DIA
UNIDADES_DIA:
    sts contador_unidades_dia, r16
    sts contador_decenas_dia, r17
    pop r17
    pop r16
    ret

ACTUALIZAR_DISPLAYS_MES:
    push r16
    push r17
    lds r16, contador_mes
    ldi r17, 0
DECENAS_MES:
    cpi r16, 10
    brlo UNIDADES_MES
    subi r16, 10
    inc r17
    rjmp DECENAS_MES
UNIDADES_MES:
    sts contador_unidades_mes, r16
    sts contador_decenas_mes, r17
    pop r17
    pop r16
    ret