
; Antirebote.asm
; Created: 30/01/2025 15:44:18
; Author : Marco Cerna V.




.include "M328DEF.inc"
.cseg
.org 0x0000

//Configuración de pila
LDI R16, LOW(RAMEND)
OUT SPL, R16 //Cargar 0xFF a SPL
LDI R16, HIGH(RAMEND)
OUT SPH, R16 //Cargar 0x08 a SPH

//Configuración de microcontrolador
SETUP:
	//COnfigurar puertos
	//PB2 --> Entrada (Con Pull-Up)
	LDI		R16, 0x00
	OUT DDRB, R16 //Configuramos Puerto D como entrada 
	LDI R16, 0xFF
	OUT PORTB, R16 //Habilitamos Pull-Up

	//PB0 ---> Salida
	LDI		R16, 0xFF
	OUT DDRB, R16  
	LDI R16, 0x01
	OUT PORTB,R16

	//Para comparar con R16 y almacenar el esrado de los botones
	LDI R17, 0xFF

	//Loop principal (MAIN)
	LOOP:
		IN R16, PIND
		CP R17,R16
		BREQ LOOP
		SBRC R16,2
		RJMP LOOP
		MOV R17, R16 //Actualizando estado de botones
		SBI PINB, 0 //Toogle PB0
		RJMP LOOP

	//Subrutinas - No interrupción
	//Subrutina - De interrupción

