/* Lab 4 Part A
   Name: Pengzhao Zhu
   Section#: 112D
   TA Name: Chris Crary
   Description: This Program configures the PWM system and output a blue hue of $0E to the blue LED
*/

.include "ATxmega128A1Udef.inc"        ;include the file
.list                                  ;list it 

.org 0x0000                            ;start our program here
rjmp MAIN                              ;jump to main

.equ stack_init=0x3FFF   ;initialize stack pointer

.org 0x100               ;start at 0x100

MAIN:
ldi r17, 0x00   ;setting for 32MHZ subroutine

rcall CLK                  ;call subroutine to set up 32MHZ clock

ldi YL, low(stack_init)    ;Load 0xFF to YL
out CPU_SPL, YL			   ;transfer to CPU_SPL
ldi YL, high(stack_init)   ;Load 0x3F to YH
out CPU_SPH, YL			   ;transfer to CPU_SPH


ldi r16, 0b01000000         ;load r16
sts PORTD_DIRSET, r16    ;set blue LED to be output

ldi r16, 0b00000100		;load r16
sts PORTD_REMAP, r16	; to move location of OC02 from Px2 and Px6

ldi r16, 0xFF           ;load r16
sts TCD0_PER, r16		;load lower byte of PER
ldi r16, 0x00			;load r16
sts TCD0_PER+1, r16		;load high byte of PER

ldi r16, 0b00000111		;load r16
sts TCD0_CTRLA, r16		;Timer clock for clk/1024

ldi r16, 0b01000011		;load r16
sts TCD0_CTRLB, r16		; bit 6 is Compare C enable. bit 2-0 is single-slope PWM

ldi r16, 0x0E			;load r16
sts TCD0_CCC, r16		;load CCC
ldi r16, 0x00			;load r16
sts TCD0_CCC+1, r16      ;setting the compare value to 0x000E

ldi r16, 0b01000000			;load r16
sts PORTD_PIN6CTRL, r16		;invert the signal because the LED are low true

DONE:
	rjmp DONE				;infinite loop


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
sts CLK_PSCTRL, r17  ;r17 will be initialized outside the subroutine for prescale. 32/8=4MHZ

pop r16          ;pop r16
ret              ;return to main routine
