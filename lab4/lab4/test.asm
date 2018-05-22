.include "ATxmega128A1Udef.inc"

.equ STACK_ADDR = 0x3FFF

.equ DUTY = 0x0F
 

.org 0x0000
	rjmp MAIN

.ORG 0x0200

MAIN:	; start main method at address 0x0200

ldi r16, low(STACK_ADDR) ; initiallize stack
out CPU_SPL, r16
ldi r16, high(STACK_ADDR)
out CPU_SPH, r16

call SETCLK32 ; call subroutine to set clock to 32 MHz

ldi r16, 0b00000111
sts TCD0_CTRLA, r16 ; enable timer/counter 0 in port d and set to prescaler 1

ldi r16, 0x43
sts TCD0_CTRLB, r16 ; enable cvhannel C in tcd0 and set mode to single slope pwm 

ldi r16, 0x00
sts	TCD0_CTRLD, r16 ; dissable events


ldi r16, 0xFF
sts TCD0_PER, r16
ldi r16,0
sts TCD0_PER +1, r16 ;load period of tcd0 with 0x0FF

ldi r16, DUTY
sts TCD0_CCC, r16
ldi r16, 0 
sts TCD0_CCC +1, r16 ; load CCC with duty cycle value 

ldi r16, 0x40
sts PORTD_DIRSET, r16 ; set pin 6 to output in port d

sts	PORTD_PIN6CTRL, r16 ; invert port d pin 6 output

ldi r16, 0x04
sts	PORTD_REMAP, r16 ; remap pin 2 pulse wave to pin 6 in portd

END:
rjmp END ; endless loop  


.ORG 0x2000


SETCLK32: ; subroutine to set clock to 32MHZ
push r16	; push r16 to stack 
ldi r16, OSC_RC32MEN_bm ; load r16 with OSC_RC32MEN_bm to activate 32MHz oscillator
sts OSC_CTRL, r16 ; store r16 in OSC_CTRL to enable 32MHz oscillator
WAIT: ; wait loop to wait for 32MHz oscillator status signal to be ready
	lds r16, OSC_STATUS ; load r16 with oscillator statuses
	andi r16, 0x02 ; bit mask status of 32MHz oscillator
	cpi r16, 0x02 ; compare value with the value that marks 32MHz oscillator as ready 
	brne WAIT ; if not ready branch back to WAIT
ldi r16, CCP_IOREG_gc ; load r16 with IOREG value to protect registers during clock change
sts CPU_CCP, r16 ; store r16 in CPU_CCP to protect registers
ldi r16, 1 ; load r16 with 1 to select 32MHz oscillator as new clock 
sts CLK_CTRL, r16 ; stores r16 in CLK_CTRL to select 32MHz oscillator as new clock 
ldi r16, CCP_IOREG_gc ; load r16 with IOREG value to protect registers during clock change
sts CPU_CCP, r16 ; store r16 in CPU_CCP to protect registers
pop r16		; pop r16 from stack 
ret	; return to program
