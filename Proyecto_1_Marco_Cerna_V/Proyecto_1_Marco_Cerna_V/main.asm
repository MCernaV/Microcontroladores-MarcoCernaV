.include "m328pdef.inc"

; Definición de pines
.equ DISPLAY_UNIDADES_MIN = PB0    ; Mismo pin utilizado para unidades del día
.equ DISPLAY_DECENAS_MIN = PB1     ; Mismo pin utilizado para decenas del día
.equ DISPLAY_UNIDADES_HORA = PB2   ; Mismo pin utilizado para unidades del mes
.equ DISPLAY_DECENAS_HORA = PB3    ; Mismo pin utilizado para decenas del mes
.equ LED_SEGUNDERO = PC5           ; Mismo pin utilizado para LED indicador
.equ BOTON_MODO = PC0              ; Botón para cambiar de modo
.equ BOTON_UP = PC1                ; Botón incrementar
.equ BOTON_DOWN = PC2              ; Botón decrementar
.equ LED_ESTADO_1 = PB4			   ; LED de estado 1
.equ LED_ESTADO_2 = PD7			   ; LED de estado 2
.equ BUZZER = PB5            ; Pin para el buzzer

; Definición de estados
.equ ESTADO_RELOJ = 0              ; Mostrar reloj
.equ ESTADO_EDITAR_MIN = 1         ; Editar minutos
.equ ESTADO_EDITAR_HORA = 2        ; Editar horas
.equ ESTADO_FECHA = 3              ; Mostrar fecha
.equ ESTADO_EDITAR_MES = 4        ; Editar mes
.equ ESTADO_EDITAR_DIA = 5         ; Editar día
.equ ESTADO_ALARMA = 6			   ; Mostrar hora de alarma
.equ ESTADO_EDITAR_ALARMA_HORA = 7   ; Editar hora de alarma
.equ ESTADO_EDITAR_ALARMA_MIN = 8    ; Editar minutos de alarma


.dseg
.org 0x0100

tabla_digitos: .byte 10

; Variables para el reloj
contador_unidades_min: .byte 1
contador_decenas_min: .byte 1
contador_unidades_hora: .byte 1
contador_decenas_hora: .byte 1
contador_minutos: .byte 1
contador_horas: .byte 1
contador_segundos: .byte 1

; Variables para la fecha (reutilizamos los mismos displays)
contador_unidades_dia: .byte 1     ; Mismo display que unidades minutos
contador_decenas_dia: .byte 1      ; Mismo display que decenas minutos
contador_unidades_mes: .byte 1     ; Mismo display que unidades horas
contador_decenas_mes: .byte 1      ; Mismo display que decenas horas
contador_dia: .byte 1
contador_mes: .byte 1

; Variables para control de estados
estado_led: .byte 1
contador_parpadeo: .byte 1
estado_actual: .byte 1             ; Variable para controlar el estado del reloj/fecha
botones_prev: .byte 1              ; Estado anterior de los botones
display_flag: .byte 1              ; Para multiplexado de displays
dias_por_mes: .byte 12            ; Almacena días por mes (31,28/29,31,30,31,30,31,31,30,31,30,31)
anio_actual: .byte 1               

; Variables adicionales para la alarma
.dseg
alarma_hora: .byte 1         ; Hora de la alarma
alarma_min: .byte 1          ; Minutos de la alarma
contador_unidades_alarma_min: .byte 1
contador_decenas_alarma_min: .byte 1
contador_unidades_alarma_hora: .byte 1
contador_decenas_alarma_hora: .byte 1
alarma_activa: .byte 1       ; 0 = desactivada, 1 = activada
alarma_sonando: .byte 1      ; 0 = no sonando, 1 = sonando

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
    ldi r16, (1<<DISPLAY_UNIDADES_MIN)|(1<<DISPLAY_DECENAS_MIN)|(1<<DISPLAY_UNIDADES_HORA)|(1<<DISPLAY_DECENAS_HORA)|(1<<LED_ESTADO_1)
    out DDRB, r16
    ldi r16, 0b01111111
    out DDRD, r16
    sbi DDRC, LED_SEGUNDERO
    
    ; Configurar pull-ups para botones
    sbi PORTC, BOTON_MODO
    sbi PORTC, BOTON_UP
    sbi PORTC, BOTON_DOWN

	; Configurar BUZZER como salida
    sbi DDRB, BUZZER
    cbi PORTB, BUZZER        ; Buzzer apagado

    ; Inicialización de variables del reloj
    ldi r16, 0
    sts contador_minutos, r16
    sts contador_horas, r16
    sts contador_segundos, r16
    sts estado_led, r16
    sts contador_parpadeo, r16
    sts estado_actual, r16     ; Iniciar en estado 0 (mostrar reloj)
    sts botones_prev, r16
    sts display_flag, r16

	; Inicializar LEDs de estado
	rcall ACTUALIZAR_LEDS_ESTADO
    
    ; Inicialización de variables de fecha
    ldi r16, 1                 ; Fecha inicial: 01/01
    sts contador_dia, r16
    sts contador_mes, r16
    ldi r16, 24                ; Año inicial: 2024
    sts anio_actual, r16

	; Inicialización de variables de alarma
    ldi r16, 7               ; Hora de alarma inicial (7:00)
    sts alarma_hora, r16
    ldi r16, 0
    sts alarma_min, r16
    sts alarma_activa, r16   ; Alarma desactivada por defecto
    sts alarma_sonando, r16  ; Alarma no está sonando inicialmente
    

    ; Inicializar tablas
    rcall INICIAR_TABLA_DIGITOS
    rcall INICIAR_TABLA_DIAS_MES
    
    ; Inicializar displays
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    rcall ACTUALIZAR_DISPLAYS_HORAS
    rcall ACTUALIZAR_DISPLAYS_DIA
    rcall ACTUALIZAR_DISPLAYS_MES

	; Actualizar displays para alarma
    rcall ACTUALIZAR_DISPLAYS_ALARMA_MIN
    rcall ACTUALIZAR_DISPLAYS_ALARMA_HORA


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
    rcall LEER_BOTONES
	rcall VERIFICAR_ALARMA
    
    ; Ejecutar la rutina correspondiente según el estado actual
    lds r16, estado_actual
    cpi r16, ESTADO_RELOJ
    breq EJECUTAR_ESTADO_0
    cpi r16, ESTADO_EDITAR_MIN
    breq EJECUTAR_ESTADO_1
    cpi r16, ESTADO_EDITAR_HORA
    breq EJECUTAR_ESTADO_2
    cpi r16, ESTADO_FECHA
    breq EJECUTAR_ESTADO_3
    cpi r16, ESTADO_EDITAR_DIA
    breq EJECUTAR_ESTADO_4
    cpi r16, ESTADO_EDITAR_MES
    breq EJECUTAR_ESTADO_5
	cpi r16, ESTADO_ALARMA
    breq EJECUTAR_ESTADO_6
    cpi r16, ESTADO_EDITAR_ALARMA_HORA
    breq EJECUTAR_ESTADO_7
    cpi r16, ESTADO_EDITAR_ALARMA_MIN
    breq EJECUTAR_ESTADO_8
    
    ; Si llegamos aquí, volver al estado 0 por seguridad
    ldi r16, ESTADO_RELOJ
    sts estado_actual, r16
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_0:
    rcall MOSTRAR_RELOJ
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_1:
    rcall MOSTRAR_EDITAR_MINUTOS
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_2:
    rcall MOSTRAR_EDITAR_HORAS
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_3:
    rcall MOSTRAR_FECHA
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_4:
    rcall MOSTRAR_EDITAR_DIA
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_5:
    rcall MOSTRAR_EDITAR_MES
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_6:
    rcall MOSTRAR_ALARMA
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_7:
    rcall MOSTRAR_EDITAR_ALARMA_HORA
    rjmp MAIN_LOOP

EJECUTAR_ESTADO_8:
    rcall MOSTRAR_EDITAR_ALARMA_MIN
    rjmp MAIN_LOOP

; ===========================================
; Inicialización de la tabla de dígitos
; ===========================================
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

; ===========================================
; Inicialización de la tabla de días por mes
; ===========================================
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

; ===========================================
; Interrupción del Timer0
; ===========================================
TIMER0_COMPA:
    push r16
    in r16, SREG
    push r16
    push r17

    ; Comprobar estado actual para manejar diferentes lógicas
    lds r17, estado_actual
    cpi r17, ESTADO_RELOJ
    brne NO_ACTUALIZAR_SEGUNDERO

    ; Control del segundero (1Hz) - Solo en estado 0
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
    rjmp FIN_TIMER_ISR

NO_ACTUALIZAR_SEGUNDERO:
    ; Para los estados FECHA, EDITAR_DIA y EDITAR_MES, parpadear el LED pero no actualizar tiempo
    cpi r17, ESTADO_FECHA
    breq PARPADEAR_LED_FECHA
    
    cpi r17, ESTADO_EDITAR_DIA
    breq PARPADEAR_LED_DIA
    
    cpi r17, ESTADO_EDITAR_MES
    breq PARPADEAR_LED_MES
    
    ; Si no es ninguno de los anteriores, mantener el LED apagado
    cbi PORTC, LED_SEGUNDERO
    rjmp FIN_TIMER_ISR
    
PARPADEAR_LED_FECHA:
PARPADEAR_LED_DIA:
PARPADEAR_LED_MES:
    ; Control del parpadeo LED para modo fecha/editar día/mes
    lds r16, contador_parpadeo
    inc r16
    cpi r16, 100
    brne ACTUALIZAR_CONTADOR_PARPADEO
    
    ldi r16, 0
    sts contador_parpadeo, r16
    
    ; Toggle LED en modo fecha/editar día
    lds r16, estado_led
    ldi r17, 1
    eor r16, r17
    sts estado_led, r16
    breq APAGAR_LED_INDICADOR
    sbi PORTC, LED_SEGUNDERO
    rjmp ACTUALIZAR_CONTADOR_PARPADEO
    
APAGAR_LED_INDICADOR:
    cbi PORTC, LED_SEGUNDERO
    
ACTUALIZAR_CONTADOR_PARPADEO:
    sts contador_parpadeo, r16

FIN_TIMER_ISR:
    pop r17
    pop r16
    out SREG, r16
    pop r16
    reti

; ===========================================
; Actualizar LEDs de estado
; ===========================================
ACTUALIZAR_LEDS_ESTADO:
    push r16
    push r17
    
    ; Obtener el estado actual
    lds r16, estado_actual
    
    ; Procesar los estados para mostrar la codificación correcta
    cpi r16, ESTADO_RELOJ        ; Estado 0 (00)
    brne CHECK_EDITAR_TIEMPO
    
    ; Modo reloj (00) - Ambos LEDs apagados
    cbi PORTB, LED_ESTADO_1
    cbi PORTD, LED_ESTADO_2
    rjmp FIN_ACTUALIZAR_LEDS
    
CHECK_EDITAR_TIEMPO:
    cpi r16, ESTADO_EDITAR_MIN   ; Estados 1 o 2 (01)
    breq MODO_EDITAR_TIEMPO
    cpi r16, ESTADO_EDITAR_HORA
    brne CHECK_MOSTRAR_FECHA
    
MODO_EDITAR_TIEMPO:
    ; Modo Edición de hora y minuto (01)
    cbi PORTB, LED_ESTADO_1
    sbi PORTD, LED_ESTADO_2
    rjmp FIN_ACTUALIZAR_LEDS
    
CHECK_MOSTRAR_FECHA:
    cpi r16, ESTADO_FECHA        ; Estado 3 (10)
    brne CHECK_EDITAR_FECHA
    
    ; Modo Mostrar fecha (10)
    sbi PORTB, LED_ESTADO_1
    cbi PORTD, LED_ESTADO_2
    rjmp FIN_ACTUALIZAR_LEDS
    
CHECK_EDITAR_FECHA:
    ; Estados 4 o 5 (11) - Editar mes o día
    sbi PORTB, LED_ESTADO_1
    sbi PORTD, LED_ESTADO_2
    
FIN_ACTUALIZAR_LEDS:
    pop r17
    pop r16
    ret

; ===========================================
; Mostrar reloj (Estado 0)
; ===========================================
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

; ===========================================
; Mostrar editar minutos (Estado 1)
; ===========================================
MOSTRAR_EDITAR_MINUTOS:
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

    ; En modo editar minutos, los displays de horas se apagan
    rcall DELAY_MULTIPLEX
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Mostrar editar horas (Estado 2)
; ===========================================
MOSTRAR_EDITAR_HORAS:
    rcall APAGAR_DISPLAYS
    ; En modo editar horas, los displays de minutos se apagan
    rcall DELAY_MULTIPLEX
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

; ===========================================
; Mostrar fecha (Estado 3)
; ===========================================
MOSTRAR_FECHA:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN  ; Mismo pin que unidades minutos
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN   ; Mismo pin que decenas minutos
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA ; Mismo pin que unidades horas
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA  ; Mismo pin que decenas horas
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Mostrar editar día (Estado 4)
; ===========================================
MOSTRAR_EDITAR_DIA:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN  ; Mismo pin que unidades minutos
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_dia
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN   ; Mismo pin que decenas minutos
    rcall DELAY_MULTIPLEX

    ; En modo editar días, los displays de mes se apagan
    rcall DELAY_MULTIPLEX
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Mostrar editar mes (Estado 5)
; ===========================================
MOSTRAR_EDITAR_MES:
    rcall APAGAR_DISPLAYS
    ; En modo editar mes, los displays de día se apagan
    rcall DELAY_MULTIPLEX
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA ; Mismo pin que unidades horas
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_mes
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA  ; Mismo pin que decenas horas
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Mostrar configuración de alarma (Estado 6)
; ===========================================
MOSTRAR_ALARMA:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_alarma_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_alarma_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_alarma_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_alarma_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    
    ; Toggle estado de alarma activada con botón UP (en estado 6)
    lds r18, estado_actual
    cpi r18, ESTADO_ALARMA
    brne FIN_MOSTRAR_ALARMA
    
    in r16, PINC
    com r16
    andi r16, (1<<BOTON_UP)
    lds r17, botones_prev
    eor r16, r17
    andi r16, (1<<BOTON_UP)
    breq FIN_MOSTRAR_ALARMA
    
    ; Toggle estado de alarma
    lds r16, alarma_activa
    ldi r17, 1
    eor r16, r17
    sts alarma_activa, r16
    
FIN_MOSTRAR_ALARMA:
    ret

; ===========================================
; Mostrar editar hora de alarma (Estado 7)
; ===========================================
MOSTRAR_EDITAR_ALARMA_HORA:
    rcall APAGAR_DISPLAYS
    ; En modo editar hora de alarma, los displays de minutos se apagan
    rcall DELAY_MULTIPLEX
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_alarma_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_alarma_hora
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Mostrar editar minutos de alarma (Estado 8)
; ===========================================
MOSTRAR_EDITAR_ALARMA_MIN:
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_alarma_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX

    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_alarma_min
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX

    ; En modo editar minutos de alarma, los displays de horas se apagan
    rcall DELAY_MULTIPLEX
    rcall DELAY_MULTIPLEX
    ret

; ===========================================
; Funciones comunes para displays
; ===========================================
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

; ===========================================
; Actualización automática del tiempo (para el estado 0)
; ===========================================
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
    sts contador_horas, r16
    
    ; Al cambiar de día, actualizar también la fecha
    rcall INCREMENTAR_DIA
    rjmp ACTUALIZAR_DISPLAYS_HORA_FINAL

GUARDAR_HORA:
    sts contador_horas, r16

ACTUALIZAR_DISPLAYS_HORA_FINAL:
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
; ===========================================
; Actualización automática del alarma (para el estado 8)
; ===========================================
ACTUALIZAR_DISPLAYS_ALARMA_MIN:
    push r16
    push r17
    lds r16, alarma_min
    ldi r17, 0
DECENAS_ALARMA_MIN:
    cpi r16, 10
    brlo UNIDADES_ALARMA_MIN
    subi r16, 10
    inc r17
    rjmp DECENAS_ALARMA_MIN
UNIDADES_ALARMA_MIN:
    sts contador_unidades_alarma_min, r16
    sts contador_decenas_alarma_min, r17
    pop r17
    pop r16
    ret

ACTUALIZAR_DISPLAYS_ALARMA_HORA:
    push r16
    push r17
    lds r16, alarma_hora
    ldi r17, 0
DECENAS_ALARMA_HORA:
    cpi r16, 10
    brlo UNIDADES_ALARMA_HORA
    subi r16, 10
    inc r17
    rjmp DECENAS_ALARMA_HORA
UNIDADES_ALARMA_HORA:
    sts contador_unidades_alarma_hora, r16
    sts contador_decenas_alarma_hora, r17
    pop r17
    pop r16
    ret

; ===========================================
; Actualización de displays para fecha
; ===========================================
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

; ===========================================
; Incrementar día (para cambio automático de fecha)
; ===========================================
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
    breq GUARDAR_DIA_INC 
    cp r16, r17
    brlo GUARDAR_DIA_INC  

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
; ===========================================
; Funciones para ajustar hora de alarma (Estado 7)
; ===========================================
INCREMENTAR_ALARMA_HORA:
    lds r16, alarma_hora
    inc r16
    cpi r16, 24
    brne GUARDAR_INC_ALARMA_HORA
    ldi r16, 0
    
GUARDAR_INC_ALARMA_HORA:
    sts alarma_hora, r16
    rcall ACTUALIZAR_DISPLAYS_ALARMA_HORA
    ret

DECREMENTAR_ALARMA_HORA:
    lds r16, alarma_hora
    cpi r16, 0
    brne NO_UNDERFLOW_ALARMA_HORA
    ldi r16, 24
    
NO_UNDERFLOW_ALARMA_HORA:
    dec r16
    sts alarma_hora, r16
    rcall ACTUALIZAR_DISPLAYS_ALARMA_HORA
    ret

; ===========================================
; Funciones para ajustar minutos de alarma (Estado 8)
; ===========================================
INCREMENTAR_ALARMA_MIN:
    lds r16, alarma_min
    inc r16
    cpi r16, 60
    brne GUARDAR_INC_ALARMA_MIN
    ldi r16, 0
    
GUARDAR_INC_ALARMA_MIN:
    sts alarma_min, r16
    rcall ACTUALIZAR_DISPLAYS_ALARMA_MIN
    ret

DECREMENTAR_ALARMA_MIN:
    lds r16, alarma_min
    cpi r16, 0
    brne NO_UNDERFLOW_ALARMA_MIN
    ldi r16, 60
    
NO_UNDERFLOW_ALARMA_MIN:
    dec r16
    sts alarma_min, r16
    rcall ACTUALIZAR_DISPLAYS_ALARMA_MIN
    ret

; ===========================================
; Lectura y manejo de botones
; ===========================================
LEER_BOTONES:
    push r16
    push r17
    push r18
    push r19
    
    ; Leer estado actual de los botones
    in r16, PINC
    com r16  ; Invertir lógica (0 = presionado)
    andi r16, (1<<BOTON_MODO)|(1<<BOTON_UP)|(1<<BOTON_DOWN)
    mov r17, r16
    
    ; Detectar flancos de bajada
    lds r18, botones_prev
    eor r18, r17      ; XOR para detectar cambios
    and r18, r17      ; AND para detectar solo los que pasaron de 0 a 1
    sts botones_prev, r17
    
    ; Verificar botón de modo
    sbrc r18, BOTON_MODO
    rcall CAMBIAR_MODO
    
    ; Verificar botones de ajuste según el estado actual
    lds r19, estado_actual
    
    cpi r19, ESTADO_RELOJ
    breq FIN_LEER_BOTONES  ; En estado reloj, los botones UP/DOWN no hacen nada
    
    cpi r19, ESTADO_EDITAR_MIN
    brne VERIFICAR_ESTADO_2
    
    ; Estado 1: editar minutos
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_MINUTOS
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_MINUTOS
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_2:
    cpi r19, ESTADO_EDITAR_HORA
    brne VERIFICAR_ESTADO_3
    
    ; Estado 2: editar horas
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_HORAS
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_HORAS
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_3:
    cpi r19, ESTADO_FECHA
    brne VERIFICAR_ESTADO_4
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_4:
    cpi r19, ESTADO_EDITAR_MES     ; Ahora el estado 4 es para editar mes
    brne VERIFICAR_ESTADO_5
    
    ; Estado 4: editar mes
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_MES_EDICION
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_MES_EDICION
    rjmp FIN_LEER_BOTONES

VERIFICAR_ESTADO_5:
    cpi r19, ESTADO_EDITAR_DIA     
    brne FIN_LEER_BOTONES
    
    ; Estado 5: editar día
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_DIA_EDICION
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_DIA_EDICION

FIN_LEER_BOTONES:
    pop r19
    pop r18
    pop r17
    pop r16
    ret
; ===========================================
; Verificar si la alarma debe sonar
; ===========================================
VERIFICAR_ALARMA:
    push r16
    push r17
    push r18
    
    ; Si la alarma no está activa, salir
    lds r16, alarma_activa
    cpi r16, 1
    brne FIN_VERIFICAR_ALARMA
    
    ; Si la alarma ya está sonando, salir
    lds r16, alarma_sonando
    cpi r16, 1
    breq ACTUALIZAR_BUZZER
    
    ; Comparar hora actual con hora de alarma
    lds r16, contador_horas
    lds r17, alarma_hora
    cp r16, r17
    brne FIN_VERIFICAR_ALARMA
    
    ; Comparar minutos actuales con minutos de alarma
    lds r16, contador_minutos
    lds r17, alarma_min
    cp r16, r17
    brne FIN_VERIFICAR_ALARMA
    
    ; Si segundos no es 0, salir (para evitar que suene durante 1 minuto)
    lds r16, contador_segundos
    cpi r16, 0
    brne FIN_VERIFICAR_ALARMA
    
    ; Activar la alarma
    ldi r16, 1
    sts alarma_sonando, r16
    
ACTUALIZAR_BUZZER:
    ; Hacer que el buzzer suene con un patrón pulsante
    lds r16, contador_parpadeo
    andi r16, 0x0F   ; Usar bits menos significativos para generar un patrón
    cpi r16, 8       ; Alternar cada 8 ciclos de interrupción
    brlo BUZZER_ON
    cbi PORTB, BUZZER
    rjmp FIN_VERIFICAR_ALARMA
    
BUZZER_ON:
    sbi PORTB, BUZZER
    
FIN_VERIFICAR_ALARMA:
    pop r18
    pop r17
    pop r16
    ret
; ===========================================
; Funciones de cambio de modo y ajustes
; ===========================================
CAMBIAR_MODO:
    ; Verificar primero si la alarma está sonando
    lds r16, alarma_sonando
    cpi r16, 1
    brne CAMBIO_MODO_NORMAL
    
    ; Si la alarma está sonando, desactivarla
    cbi PORTB, BUZZER
    ldi r16, 0
    sts alarma_sonando, r16
    ret
    
CAMBIO_MODO_NORMAL:
    lds r16, estado_actual
    inc r16
    cpi r16, 9       ; Ahora tenemos 9 estados (0-8)
    brlt GUARDAR_ESTADO
    ldi r16, 0       ; Volver al estado 0
    
GUARDAR_ESTADO:
    sts estado_actual, r16
    rcall ACTUALIZAR_LEDS_ESTADO
    ret

; ===========================================
; Funciones para ajustar minutos (Estado 1)
; ===========================================
INCREMENTAR_MINUTOS:
    lds r16, contador_minutos
    inc r16
    cpi r16, 60
    brne GUARDAR_INC_MIN
    ldi r16, 0
    
GUARDAR_INC_MIN:
    sts contador_minutos, r16
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    ret

DECREMENTAR_MINUTOS:
    lds r16, contador_minutos
    cpi r16, 0
    brne NO_UNDERFLOW_MIN
    ldi r16, 60
    
NO_UNDERFLOW_MIN:
    dec r16
    sts contador_minutos, r16
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    ret

; ===========================================
; Funciones para ajustar horas (Estado 2)
; ===========================================
INCREMENTAR_HORAS:
    lds r16, contador_horas
    inc r16
    cpi r16, 24
    brne GUARDAR_INC_HORA
    ldi r16, 0
    
GUARDAR_INC_HORA:
    sts contador_horas, r16
    rcall ACTUALIZAR_DISPLAYS_HORAS
    ret

DECREMENTAR_HORAS:
    lds r16, contador_horas
    cpi r16, 0
    brne NO_UNDERFLOW_HORA
    ldi r16, 24
    
NO_UNDERFLOW_HORA:
    dec r16
    sts contador_horas, r16
    rcall ACTUALIZAR_DISPLAYS_HORAS
    ret

; ===========================================
; Funciones para incrementar/decrementar día manualmente (Estado 3)
; ===========================================
INCREMENTAR_DIA_MANUAL:
    rcall INCREMENTAR_DIA
    ret

DECREMENTAR_DIA_MANUAL:
    lds r16, contador_dia
    cpi r16, 1
    brne NO_UNDERFLOW_DIA_MANUAL
    
    ; Si día = 1, retroceder al mes anterior
    lds r17, contador_mes
    cpi r17, 1
    brne NO_UNDERFLOW_MES_DIA_MANUAL
    
    ; Si mes = 1, ir a mes 12 y decrementar año
    ldi r17, 12
    sts contador_mes, r17
    
    ; Decrementar año
    lds r18, anio_actual
    cpi r18, 0
    brne NO_UNDERFLOW_ANIO
    ldi r18, 99   ; Si año = 0, año = 99
NO_UNDERFLOW_ANIO:
    dec r18
    sts anio_actual, r18
    
    ; Actualizar tabla de días por mes (por si cambió febrero)
    rcall INICIAR_TABLA_DIAS_MES
    rjmp OBTENER_MAX_DIA_MES_ANTERIOR
    
NO_UNDERFLOW_MES_DIA_MANUAL:
    dec r17
    sts contador_mes, r17
    
OBTENER_MAX_DIA_MES_ANTERIOR:
    ; Obtener días del mes anterior
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    lds r18, contador_mes
    dec r18          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r18
    brcc PC+2
    inc ZH
    ld r16, Z        ; r16 contiene el número de días del mes anterior
    sts contador_dia, r16
    rcall ACTUALIZAR_DISPLAYS_MES
    rjmp ACTUALIZAR_DIA_MANUAL_FINAL
    
NO_UNDERFLOW_DIA_MANUAL:
    dec r16
    sts contador_dia, r16
    
ACTUALIZAR_DIA_MANUAL_FINAL:
    rcall ACTUALIZAR_DISPLAYS_DIA
    ret

; ===========================================
; Funciones para ajustar día (Estado 4)
; ===========================================
INCREMENTAR_DIA_EDICION:
    lds r16, contador_dia
    inc r16
    
    ; Obtener máximo días para el mes actual
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    lds r17, contador_mes
    dec r17          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r17
    brcc PC+2
    inc ZH
    ld r17, Z        ; r17 contiene el número de días del mes actual
    
    ; Comparar con el máximo
    cp r16, r17
    brsh OVER_MAX_DIA  ; If r16 >= r17 (replacement for brle's inverse logic)
    rjmp GUARDAR_INC_DIA
    
OVER_MAX_DIA:
    ldi r16, 1       ; Si se supera el máximo, volver a día 1
    
GUARDAR_INC_DIA:      ; This label was missing in your error list
    sts contador_dia, r16
    rcall ACTUALIZAR_DISPLAYS_DIA
    ret

; ===========================================
; Función para decrementar día en modo edición (Estado 4)
; ===========================================
DECREMENTAR_DIA_EDICION:
    lds r16, contador_dia
    cpi r16, 1
    brne NO_UNDERFLOW_DIA_EDICION
    
    ; Si día = 1, ir al último día del mes
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    lds r17, contador_mes
    dec r17          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r17
    brcc PC+2
    inc ZH
    ld r16, Z        ; r16 contiene el número de días del mes actual
    rjmp GUARDAR_DEC_DIA_EDICION
    
NO_UNDERFLOW_DIA_EDICION:
    dec r16
    
GUARDAR_DEC_DIA_EDICION:
    sts contador_dia, r16
    rcall ACTUALIZAR_DISPLAYS_DIA
    ret

INCREMENTAR_MES_EDICION:
    lds r16, contador_mes
    inc r16
    cpi r16, 13
    brne GUARDAR_INC_MES
    ldi r16, 1       ; Si mes > 12, mes = 1
    
GUARDAR_INC_MES:
    sts contador_mes, r16
    
    ; Verificar que el día actual no supere los días del nuevo mes
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    dec r16          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r16
    brcc PC+2
    inc ZH
    ld r17, Z        ; r17 contiene el número de días del nuevo mes
    
    lds r16, contador_dia
    cp r16, r17
    brsh ADJUST_DAY_MAX  ; If r16 >= r17 (replacement for brle's inverse logic)
    rjmp ACTUALIZAR_MES_EDICION
    
ADJUST_DAY_MAX:
    ; Si día > máximo días del mes, ajustar al máximo
    sts contador_dia, r17
    rcall ACTUALIZAR_DISPLAYS_DIA
    
ACTUALIZAR_MES_EDICION:  ; This label was missing in your error list
    rcall ACTUALIZAR_DISPLAYS_MES
    ret

; For DECREMENTAR_MES_EDICION function
DECREMENTAR_MES_EDICION:
    lds r16, contador_mes
    cpi r16, 1
    brne NO_UNDERFLOW_MES
    ldi r16, 12      ; Si mes = 1, mes = 12
    
NO_UNDERFLOW_MES:
    dec r16
    sts contador_mes, r16
    
    ; Verificar que el día actual no supere los días del nuevo mes
    ldi ZH, HIGH(dias_por_mes)
    ldi ZL, LOW(dias_por_mes)
    dec r16          ; Los meses van de 1-12, pero el array va de 0-11
    add ZL, r16
    brcc PC+2
    inc ZH
    ld r17, Z        ; r17 contiene el número de días del nuevo mes
    
    lds r16, contador_dia
    cp r16, r17
    brsh ADJUST_DAY_MAX_DEC  ; If r16 >= r17 (replacement for brle's inverse logic)
    rjmp ACTUALIZAR_MES_DEC_EDICION
    
ADJUST_DAY_MAX_DEC:
    ; Si día > máximo días del mes, ajustar al máximo
    sts contador_dia, r17
    rcall ACTUALIZAR_DISPLAYS_DIA
    
ACTUALIZAR_MES_DEC_EDICION:  ; This label was missing in your error list
    rcall ACTUALIZAR_DISPLAYS_MES
    ret