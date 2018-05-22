/* Lab 4 Part D
   Name: Pengzhao Zhu
   Section#: 112D
   TA Name: Chris Crary
   Description: This Program configures the Xmega port interrupt to trigger when S1 is pressed.
				It will then output how many time S1 has been pressed to the 8 LED. 
				Debounced performed with a second timer interrupt. Added to the first interrupt
*/


.include "ATxmega128A1Udef.inc"        ;include the file
.list                                  ;list it 

.org 0x0000                            ;start our program here
rjmp MAIN                              ;jump to main

.org PORTF_INT0_vect				;tell the uP where to jump to when edge interrupt is triggered
	rjmp ISR

.org TCD0_OVF_vect					;tell the uP where to jump to when timre interrupt is triggered
	rjmp TIMER_ISR

.equ stack_init=0x3FFF   ;initialize stack pointer
.equ debounce_timer= (32000000*.005)/1024			;.equ for the PER value of the timer interrupt

.org 0x100

MAIN:
ldi r23, 0x00   ;setting for 32MHZ subroutine. 

ldi r17, 0x00   ;counter register for how many time the ISR has been executed

rcall CLK			;call CLK to configure 32MHZ clock

ldi YL, low(stack_init)    ;Load 0xFF to YL
sts CPU_SPL, YL			   ;transfer to CPU_SPL
ldi YL, high(stack_init)   ;Load 0x3F to YH
sts CPU_SPH, YL			   ;transfer to CPU_SPH

ldi r16, 0xFF
sts PORTC_DIRSET, r16    ;set the 8 LED to be output
sts PORTC_OUT, r16       ;turn the 8 active low LED off

ldi r16, 0x40
sts PORTD_DIRSET, r16    ;set the RGB LED to be output
sts PORTD_OUT, r16       ;turn the RGB LED off

rcall DEBOUNCE


ldi r16, 0x70

LOOP:
sts PORTD_OUTTGL, r16                 ;keep toggling the BLUE LED
rjmp LOOP
	

DEBOUNCE:
push r16
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
	
pop r16
ret

ISR: 
push r18										;push the necessary registers. including the status register
lds r18, CPU_SREG
push r18
push r16

ldi r16, 0x00                                  ;setting the CNT back to zero
sts TCD0_CNT, r16

ldi r16, low(debounce_timer)                    ;set the timer for 5ms to debounce
sts TCD0_PER, r16								;need to load low and high byte of PER
ldi r16, high(debounce_timer)
sts TCD0_PER+1, r16

ldi r16, 0b00000111                           ;Timer clock for clk/1024
sts TCD0_CTRLA, r16 

ldi r16, 0x01                                    ;enable timer interrupt
sts TCD0_INTCTRLA, r16 

ldi r16, 0x00                                     ;disable PortF external interrupt
sts PORTF_INTCTRL, r16
	
pop r16											;pop the necessary registers. including the status register
pop r18
sts CPU_SREG, r18
pop r18
reti

TIMER_ISR:
push r18								;push the necessary registers. including the status register
lds r18, CPU_SREG
push r18
push r16

ldi r16, 0x00                           ;disable timer
sts TCD0_CTRLA, r16 

ldi r16, 0x00
sts TCD0_INTCTRLA, r16					;disable timer interrupt

lds r16, PORTF_IN       ;to check if switch is still active
bst r16, 2
brts NOT_ACTIVE

inc r17             ;to increase r17 by 1 everytime the ISR is executed
com r17             ;takes one's complement of r17 because LED are active low

sts PORTC_OUT, r17
com r17             ;takes one's complement again so r17 is correct the next time we execuate the ISR

NOT_ACTIVE:
ldi r16, 0x01                                    ;enable PortF external interrupt
sts PORTF_INTCTRL, r16

ldi r16, 0x01                                    ;clear the interrupt flag
sts PORTF_INTFLAGS, r16

pop r16                                          ;prepare to return from interrupt
pop r18
sts CPU_SREG, r18								;pop the necessary registers. including the status register
pop r18
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