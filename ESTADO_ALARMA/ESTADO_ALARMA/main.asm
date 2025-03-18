.include "m328pdef.inc"

; ===========================================
; Definiciones para la alarma y estados
; ===========================================
.equ BUZZER = PB5                    ; Pin para el buzzer
.equ ESTADO_NORMAL = 0               ; Estado normal (mostrar hora)
.equ ESTADO_EDITAR_HORA = 1          ; Estado para editar hora actual
.equ ESTADO_EDITAR_MINUTO = 2        ; Estado para editar minutos actuales
.equ ESTADO_ALARMA = 3               ; Estado para configurar alarma
.equ ESTADO_ALARMA_HORA = 4          ; Estado para configurar hora de alarma
.equ ESTADO_ACTIVAR_ALARMA = 5       ; Estado para activar/desactivar alarma

; Definiciones para displays
.equ DISPLAY_DECENAS_MIN = 0         ; PB0 - Display decenas minutos
.equ DISPLAY_UNIDADES_MIN = 1        ; PB1 - Display unidades minutos
.equ DISPLAY_DECENAS_HORA = 2        ; PB2 - Display decenas horas
.equ DISPLAY_UNIDADES_HORA = 3       ; PB3 - Display unidades horas

; Definiciones para botones
.equ BOTON_UP = 0                    ; PINC0 - Botón incrementar
.equ BOTON_DOWN = 1                  ; PINC1 - Botón decrementar
.equ BOTON_MODO = 2                  ; PINC2 - Botón cambiar modo
.equ BOTON_ALARMA = 3       ; Botón para activar/desactivar la alarma


; ===========================================
; Sección de datos
; ===========================================
.dseg

	; Inicializar variables de hora actual
	ldi r16, 0
	sts contador_segundos, r16
	sts contador_minutos, r16
	sts contador_horas, r16
	sts contador_unidades_min, r16
	sts contador_decenas_min, r16
	sts contador_unidades_hora, r16
	sts contador_decenas_hora, r16
    
    ; Variables para la alarma
    contador_minutos_alarma: .byte 1
    contador_horas_alarma: .byte 1
    contador_unidades_min_alarma: .byte 1
    contador_decenas_min_alarma: .byte 1
    contador_unidades_hora_alarma: .byte 1
    contador_decenas_hora_alarma: .byte 1
    estado_alarma_configurando: .byte 1  ; 0 = configurando minutos, 1 = configurando horas
    alarma_activada: .byte 1             ; 0 = alarma inactiva, 1 = alarma activa
    alarma_sonando: .byte 1              ; 0 = alarma no sonando, 1 = alarma sonando

; ===========================================
; Sección de código
; ===========================================
.cseg
.org 0x0000
    rjmp RESET                       ; Vector de reset
    
    ; Vector para timers según la configuración
.org 0x001A
    rjmp TIMER0_COMPA                ; Vector para Timer0 Compare Match A

; ===========================================
; Inicialización
; ===========================================
RESET:
    ; Configuración del stack pointer
    ldi r16, high(RAMEND)
    out SPH, r16
    ldi r16, low(RAMEND)
    out SPL, r16
    
    ; Configuración de puertos
    ldi r16, 0xFF
    out DDRD, r16                    ; PORTD como salida para segmentos
    ldi r16, 0x2F                    ; Bits 0-3 y 5 como salidas (displays + buzzer)
    out DDRB, r16                    
    
    ; Configurar PORTC como entrada para botones con pull-ups
    ldi r16, 0x00
    out DDRC, r16                    ; PORTC como entrada
    ldi r16, 0x07                    ; Pull-ups para los 3 botones
    out PORTC, r16
    
    ; Inicializar variables de hora actual
    ldi r16, 0
    sts contador_segundos, r16
    sts contador_minutos, r16
    sts contador_horas, r16
    sts contador_unidades_min, r16
    sts contador_decenas_min, r16
    sts contador_unidades_hora, r16
    sts contador_decenas_hora, r16
    
    ; Inicializar variables de alarma
    sts contador_minutos_alarma, r16
    sts contador_horas_alarma, r16
    sts contador_unidades_min_alarma, r16
    sts contador_decenas_min_alarma, r16
    sts contador_unidades_hora_alarma, r16
    sts contador_decenas_hora_alarma, r16
    sts estado_alarma_configurando, r16
    sts alarma_activada, r16
    sts alarma_sonando, r16
    
    ; Asegurar que el buzzer esté apagado inicialmente
    cbi PORTB, BUZZER
    
    ; Configuración del Timer0 para generar interrupciones a 1Hz
    ldi r16, (1<<WGM01)              ; Modo CTC
    out TCCR0A, r16
    ldi r16, (1<<CS02) | (1<<CS00)   ; Prescaler 1024
    out TCCR0B, r16
    ldi r16, 155                     ; Valor para generar aproximadamente 1Hz
    out OCR0A, r16
    ldi r16, (1<<OCIE0A)             ; Habilitar interrupción Compare Match A
    sts TIMSK0, r16
    
    ; Habilitar interrupciones globales
    sei
    
    ; Estado inicial
    ldi r19, ESTADO_NORMAL           ; Iniciar en estado normal (mostrar hora)

; ===========================================
; Bucle principal
; ===========================================
MAIN_LOOP:
    ; Procesar el estado actual
    cpi r19, ESTADO_NORMAL
    breq MOSTRAR_HORA
    
    cpi r19, ESTADO_EDITAR_HORA
    breq EJECUTAR_ESTADO_EDITAR_HORA
    
    cpi r19, ESTADO_EDITAR_MINUTO
    breq EJECUTAR_ESTADO_EDITAR_MINUTO
    
    cpi r19, ESTADO_ALARMA
    breq EJECUTAR_ESTADO_ALARMA
    
    cpi r19, ESTADO_ALARMA_HORA
    breq EJECUTAR_ESTADO_ALARMA_HORA
    
    cpi r19, ESTADO_ACTIVAR_ALARMA
    breq EJECUTAR_ESTADO_ACTIVAR_ALARMA
    
    ; Si no coincide con ningún estado, volver al estado normal
    ldi r19, ESTADO_NORMAL
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 0 - Mostrar hora actual
; ===========================================
MOSTRAR_HORA:
    rcall LEER_BOTONES               ; Leer estado de botones
    
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
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 1 - Editar hora actual
; ===========================================
EJECUTAR_ESTADO_EDITAR_HORA:
    rcall LEER_BOTONES               ; Leer estado de botones
    
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
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 2 - Editar minutos actuales
; ===========================================
EJECUTAR_ESTADO_EDITAR_MINUTO:
    rcall LEER_BOTONES               ; Leer estado de botones
    
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
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 6 - Configurar minutos de alarma
; ===========================================
EJECUTAR_ESTADO_ALARMA:
    rcall LEER_BOTONES               ; Leer estado de botones
    
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_min_alarma
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_min_alarma
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 11                      ; Código para apagado (puedes usar un índice fuera del rango 0-9)
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 11                      ; Código para apagado
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 7 - Configurar horas de alarma
; ===========================================
EJECUTAR_ESTADO_ALARMA_HORA:
    rcall LEER_BOTONES               ; Leer estado de botones
    
    rcall APAGAR_DISPLAYS
    ldi r16, 11                      ; Código para apagado
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 11                      ; Código para apagado
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    lds r16, contador_unidades_hora_alarma
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    lds r16, contador_decenas_hora_alarma
    rcall MOSTRAR_DIGITO
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina del Estado 8 - Activar/Desactivar alarma
; ===========================================
EJECUTAR_ESTADO_ACTIVAR_ALARMA:
    rcall LEER_BOTONES               ; Leer estado de botones
    
    rcall APAGAR_DISPLAYS
    ; Mostrar "AL" en los displays de minutos
    ldi r16, 0x88                    ; Código para 'A'
    out PORTD, r16
    sbi PORTB, DISPLAY_DECENAS_MIN
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 0xC7                    ; Código para 'L'
    out PORTD, r16
    sbi PORTB, DISPLAY_UNIDADES_MIN
    rcall DELAY_MULTIPLEX
    
    ; Mostrar "On" u "OF" según estado
    rcall APAGAR_DISPLAYS
    lds r16, alarma_activada
    cpi r16, ALARMA_ACTIVA
    brne MOSTRAR_OFF_STATE
    
    ; Mostrar "On"
    ldi r16, 0xC0                    ; Código para 'O'
    out PORTD, r16
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 0xAB                    ; Código para 'n'
    out PORTD, r16
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX
    rjmp MAIN_LOOP
    
MOSTRAR_OFF_STATE:
    ; Mostrar "OF"
    ldi r16, 0xC0                    ; Código para 'O'
    out PORTD, r16
    sbi PORTB, DISPLAY_DECENAS_HORA
    rcall DELAY_MULTIPLEX
    
    rcall APAGAR_DISPLAYS
    ldi r16, 0x8E                    ; Código para 'F'
    out PORTD, r16
    sbi PORTB, DISPLAY_UNIDADES_HORA
    rcall DELAY_MULTIPLEX
    
    rjmp MAIN_LOOP

; ===========================================
; Rutina para leer botones
; ===========================================
LEER_BOTONES:
    in r18, PINC                     ; Leer estado de botones desde PINC
    com r18                          ; Invertir bits (botones activos en bajo)
    andi r18, 0x07                   ; Mantener solo los bits de los 3 botones
    
    ; Verificar botón MODO para cambio de estado
    sbrs r18, BOTON_MODO
    rjmp VERIFICAR_ALARMA_SONANDO    ; Si no está presionado, verificar otros botones
    
    ; Botón MODO presionado - cambiar estado
    lds r16, alarma_sonando
    cpi r16, 1
    brne NO_ALARMA_SONANDO
    
    ; Si la alarma está sonando, apagarla y continuar mostrando la hora
    rcall APAGAR_ALARMA
    ldi r19, ESTADO_NORMAL
    rjmp FIN_LEER_BOTONES
    
NO_ALARMA_SONANDO:
    ; Cambiar estado según el actual
    cpi r19, ESTADO_NORMAL
    brne VERIFICAR_ESTADO_EDITAR_HORA
    ldi r19, ESTADO_EDITAR_HORA      ; Normal -> Editar hora
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_EDITAR_HORA:
    cpi r19, ESTADO_EDITAR_HORA
    brne VERIFICAR_ESTADO_EDITAR_MINUTO
    ldi r19, ESTADO_EDITAR_MINUTO    ; Editar hora -> Editar minutos
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_EDITAR_MINUTO:
    cpi r19, ESTADO_EDITAR_MINUTO
    brne VERIFICAR_ESTADO_ALARMA
    ldi r19, ESTADO_ALARMA           ; Editar minuto -> Config minutos alarma
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_ALARMA:
    cpi r19, ESTADO_ALARMA
    brne VERIFICAR_ESTADO_ALARMA_HORA
    ldi r19, ESTADO_ALARMA_HORA      ; Config minutos -> Config horas
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_ALARMA_HORA:
    cpi r19, ESTADO_ALARMA_HORA
    brne VERIFICAR_ESTADO_ACTIVAR
    ldi r19, ESTADO_ACTIVAR_ALARMA   ; Config horas -> Activar/Desactivar
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_ESTADO_ACTIVAR:
    cpi r19, ESTADO_ACTIVAR_ALARMA
    brne FIN_LEER_BOTONES
    ldi r19, ESTADO_NORMAL           ; Activar/Desactivar -> Normal
    rjmp FIN_LEER_BOTONES

; ===========================================
; Rutinas para manipular alarma
; ===========================================
INCREMENTAR_HORAS:
    lds r16, contador_horas
    inc r16
    cpi r16, 24
    brne GUARDAR_INC_HORA
    ldi r16, 0
    
GUARDAR_INC_HORA:
    sts contador_horas, r16
    rcall ACTUALIZAR_DISPLAYS_HORA
    ret

DECREMENTAR_HORAS:
    lds r16, contador_horas
    cpi r16, 0
    brne NO_UNDERFLOW_HORA
    ldi r16, 24
    
NO_UNDERFLOW_HORA:
    dec r16
    sts contador_horas, r16
    rcall ACTUALIZAR_DISPLAYS_HORA
    ret

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

ACTIVAR_ALARMA:
    ldi r16, ALARMA_ACTIVA
    sts alarma_activada, r16
    ret

DESACTIVAR_ALARMA:
    ldi r16, ALARMA_INACTIVA
    sts alarma_activada, r16
    ; Si la alarma está sonando, también apagarla
    rcall APAGAR_ALARMA
    ret

APAGAR_ALARMA:
    ldi r16, 0
    sts alarma_sonando, r16
    cbi PORTB, BUZZER  ; Apagar el buzzer
    ret

; ===========================================
; Rutinas para actualizar displays
; ===========================================
ACTUALIZAR_DISPLAYS_HORA:
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
    ret

ACTUALIZAR_DISPLAYS_MINUTOS:
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
    ret

ACTUALIZAR_DISPLAYS_MINUTOS_ALARMA:
    lds r16, contador_minutos_alarma
    ldi r17, 0
DECENAS_MIN_ALARMA:
    cpi r16, 10
    brlo UNIDADES_MIN_ALARMA
    subi r16, 10
    inc r17
    rjmp DECENAS_MIN_ALARMA
UNIDADES_MIN_ALARMA:
    sts contador_unidades_min_alarma, r16
    sts contador_decenas_min_alarma, r17
    ret

ACTUALIZAR_DISPLAYS_HORAS_ALARMA:
    lds r16, contador_horas_alarma
    ldi r17, 0
DECENAS_HORA_ALARMA:
    cpi r16, 10
    brlo UNIDADES_HORA_ALARMA
    subi r16, 10
    inc r17
    rjmp DECENAS_HORA_ALARMA
UNIDADES_HORA_ALARMA:
    sts contador_unidades_hora_alarma, r16
    sts contador_decenas_hora_alarma, r17
    ret

; ===========================================
; Rutina para mostrar dígito en display
; ===========================================
MOSTRAR_DIGITO:
    cpi r16, 0
    brne CHECK_1
    ldi r17, 0xC0      ; Código para '0'
    rjmp MOSTRAR
CHECK_1:
    cpi r16, 1
    brne CHECK_2
    ldi r17, 0xF9      ; Código para '1'
    rjmp MOSTRAR
CHECK_2:
    cpi r16, 2
    brne CHECK_3
    ldi r17, 0xA4      ; Código para '2'
    rjmp MOSTRAR
CHECK_3:
    cpi r16, 3
    brne CHECK_4
    ldi r17, 0xB0      ; Código para '3'
    rjmp MOSTRAR
CHECK_4:
    cpi r16, 4
    brne CHECK_5
    ldi r17, 0x99      ; Código para '4'
    rjmp MOSTRAR
CHECK_5:
    cpi r16, 5
    brne CHECK_6
    ldi r17, 0x92      ; Código para '5'
    rjmp MOSTRAR
CHECK_6:
    cpi r16, 6
    brne CHECK_7
    ldi r17, 0x82      ; Código para '6'
    rjmp MOSTRAR
CHECK_7:
    cpi r16, 7
    brne CHECK_8
    ldi r17, 0xF8      ; Código para '7'
    rjmp MOSTRAR
CHECK_8:
    cpi r16, 8
    brne CHECK_9
    ldi r17, 0x80      ; Código para '8'
    rjmp MOSTRAR
CHECK_9:
    cpi r16, 9
    brne CHECK_APAGADO
    ldi r17, 0x90      ; Código para '9'
    rjmp MOSTRAR
CHECK_APAGADO:
    ldi r17, 0xFF      ; Código para apagado
MOSTRAR:
    out PORTD, r17
    ret

; ===========================================
; Rutinas de soporte para displays
; ===========================================
APAGAR_DISPLAYS:
    cbi PORTB, DISPLAY_DECENAS_MIN
    cbi PORTB, DISPLAY_UNIDADES_MIN
    cbi PORTB, DISPLAY_DECENAS_HORA
    cbi PORTB, DISPLAY_UNIDADES_HORA
    ret

DELAY_MULTIPLEX:
    push r20
    push r21
    ldi r20, 0x10
LOOP_DELAY:
    ldi r21, 0xFF
INNER_LOOP_DELAY:
    dec r21
    brne INNER_LOOP_DELAY
    dec r20
    brne LOOP_DELAY
    pop r21
    pop r20
    ret

; ===========================================
; Interrupción del Timer0 para actualizar tiempo
; ===========================================
TIMER0_COMPA:
    push r16
    in r16, SREG
    push r16                         ; Guardar SREG
    
    ; Incrementar segundos
    lds r16, contador_segundos
    inc r16
    cpi r16, 60
    brne GUARDAR_SEGUNDOS
    
    ; Si alcanza 60 segundos, incrementar minutos
    ldi r16, 0
    lds r17, contador_minutos
    inc r17
    cpi r17, 60
    brne GUARDAR_MINUTOS
    
    ; Si alcanza 60 minutos, incrementar horas
    ldi r17, 0
    lds r18, contador_horas
    inc r18
    cpi r18, 24
    brne GUARDAR_HORAS
    
    ; Si alcanza 24 horas, reiniciar a 0
    ldi r18, 0
    
GUARDAR_HORAS:
    sts contador_horas, r18
    rcall ACTUALIZAR_DISPLAYS_HORA
    
GUARDAR_MINUTOS:
    sts contador_minutos, r17
    rcall ACTUALIZAR_DISPLAYS_MINUTOS
    
GUARDAR_SEGUNDOS:
    sts contador_segundos, r16
    
    ; Verificar si debe sonar la alarma
    rcall VERIFICAR_ALARMA
    
    pop r16
    out SREG, r16                    ; Restaurar SREG
    pop r16
    reti

; ===========================================
; Verificar si debe activarse la alarma
; ===========================================
VERIFICAR_BOTONES_POR_ESTADO:
    ; Verificar botones UP/DOWN según el estado actual
    cpi r19, ESTADO_EDITAR_HORA
    brne VERIFICAR_BOTONES_ESTADO_MINUTO
    
    ; Estado 1: editar horas
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_HORAS
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_HORAS
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_BOTONES_ESTADO_MINUTO:
    cpi r19, ESTADO_EDITAR_MINUTO
    brne VERIFICAR_BOTONES_ESTADO_ALARMA
    
    ; Estado 2: editar minutos
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_MINUTOS
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_MINUTOS
    rjmp FIN_LEER_BOTONES
    
VERIFICAR_BOTONES_ESTADO_ALARMA:
    cpi r19, ESTADO_ALARMA
    brne VERIFICAR_BOTONES_ESTADO_HORA_ALARMA
    
    ; Estado 3: configurar minutos de alarma
    sbrc r18, BOTON_UP
    rcall INCREMENTAR_MINUTOS_ALARMA
    
    sbrc r18, BOTON_DOWN
    rcall DECREMENTAR_MINUTOS_ALARMA
    rjmp FIN_LEER_BOTONES