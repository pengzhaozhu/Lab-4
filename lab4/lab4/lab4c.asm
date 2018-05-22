/* Lab 4 Part C
   Name: Pengzhao Zhu
   Section#: 112D
   TA Name: Chris Crary
   Description: This Program configures the Xmega port interrupt to trigger when S1 is pressed.
				It will then output how many time S1 has been pressed to the 8 LED. 
				No debounce performed
*/



.include "ATxmega128A1Udef.inc"        ;include the file
.list                                  ;list it 

.org 0x0000                            ;start our program here
rjmp MAIN                              ;jump to main

.org PORTF_INT0_vect                  ;tell the ISR where to jump to
	rjmp ISR

.equ stack_init=0x3FFF   ;initialize stack pointer

.org 0x100

MAIN:
ldi r23, 0x00   ;setting for 32MHZ subroutine. 

ldi r17, 0x00   ;counter register for how many time the ISR has been executed

rcall CLK

ldi YL, low(stack_init)    ;Load 0xFF to YL
sts CPU_SPL, YL			   ;transfer to CPU_SPL
ldi YL, high(stack_init)   ;Load 0x3F to YH
sts CPU_SPH, YL			   ;transfer to CPU_SPH

ldi r16, 0xFF
sts PORTC_DIRSET, r16    ;set the 8 LED to be output
sts PORTC_OUT, r16       ;turn the 8 active low LED off

ldi r16, 0x40
sts PORTD_DIRSET, r16    ;set the BLUE LED to be output
sts PORTD_OUT, r16       ;set the BLUE LED to be output


ldi r16, 0x01         ;enable low level interrupt for INT0
sts PORTF_INTCTRL, r16

ldi r16, 0x04
sts PORTF_INT0MASK, r16    ;set PF2 (tactile switch S1) as the source for INT0

sts PORTF_DIRCLR, r16    ;set PF2 (tactile switch S1) as input

ldi r16, 0b00000010     ; the last 3 bits "010" corresponds to falling edge sense trigger
sts PORTF_PIN2CTRL, r16

ldi r16, 0x01 
sts PMIC_CTRL, r16      ;enable low level interrupt in the PMIC

sei    ;setting the I bit

ldi r16, 0x70							;0x70 to toggle the pin. Used in the infinite loop

LOOP:
	sts PORTD_OUTTGL, r16              ;keep toggling the LED
	rjmp LOOP							;infinite loop in the main code
	

ISR:
	push r19						;push the necessary registers and also the status register
	push r18
	lds r18, CPU_SREG
	push r18
	inc r17             ;to increase r17 by 1 everytime the ISR is executed
	com r17             ;takes one's complement of r17 because LED are active low
	sts PORTC_OUT, r17
	com r17             ;takes one's complement again so r17 is correct the next time we execuate the ISR

	ldi r19, 0x01						;load r19
	sts PORTF_INTFLAGS, r19				;clear the interrupt flag

	pop r18							;return the registers to their original value. including the status register
	sts CPU_SREG, r18
	pop r18
	pop r19
	reti


CLK:   ;take in a r17 value for prescaler. 32MHZ = 0x00 for prescale
push r16              ;push r16
ldi r16, 0b00000010   ;bit 1 is the 32Mhz oscillator
sts OSC_CTRL, r16     ;store r16 into the OSC_CTRL

NSTABLE:
lds r16, OSC_STATUS     ;load oscillator status into r16
bst r16, 1              ;check if 32Mhz oscillator is stable
brts STABLE             ;branch if stable
brtc NSTABLE            ;loop again if non-stable

STABLE:
ldi r16, 0xD8   ;writing IOREG to r16
sts CPU_CCP, r16 ;write IOREG to CPU_CCP to enable change 
ldi r16, 0b00000001  ;write this to r16. corresponds to 32Mhz oscillator
sts CLK_CTRL, r16    ;select the 32Mhz oscillator

ldi r16, 0xD8    ;writing IOREG for prescaler
sts CPU_CCP, r16 ;for prescaler
sts CLK_PSCTRL, r23  ;r17 will be initialized outside the subroutine for prescale. 32/8=4MHZ

pop r16          ;pop r16
ret              ;return to main routine