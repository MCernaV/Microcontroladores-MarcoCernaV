;
; Interrupciones.asm
;
; Created: 13/02/2025 15:15:48
; Author : marco
;

.org 0x0000
	RJMP START
.org 0x0020

//Desabilitar las interrupciones de esa linea hacia abajo. (Se deben volver a encender)
CLI
LDI R16, (1<< CLKPCE)
STS CLKPR, R16
LDI R16, 100
OUT TCNT0, R16


SEI // Para habilitar de nuevo las interrupciones de esta linea hacia abajo




