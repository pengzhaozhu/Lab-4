.include "ATxmega128A1Udef.inc"        ;include the file
.list                                  ;list it 

.org 0x0000                            ;start our program here
rjmp MAIN                              ;jump to main

.org PORTF_INT0_vect       ;for the edge trigger debounce interrupt
	rjmp ISR

.org TCC0_OVF_vect       ;for the 5 ms timer debounce interrupt
	rjmp TIMER_ISR

.org TCE0_OVF_vect       ;for the .1 second blink timer interrupt
	rjmp BLINK_ISR

.equ stack_init=0x3FFF   ;initialize stack pointer
.equ debounce_timer= (32000000*.005)/1024
.equ blink_timer =(32000000*.1)/1024

.org 0x100
Table: .db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 
Table1:.db 0x9A, 0x2C, 0x8A, 0x07, 0xFF, 0x49
Table2:.db 0x1F, 0x1F, 0xC2, 0x0D, 0x8D, 0x3C
Table3:.db 0x16, 0x46, 0xFA, 0xA5, 0x21, 0x00

.org 0x200

MAIN:
ldi r23, 0x00   ;setting for 32MHZ subroutine. 

ldi r17, 0x00   ;counter register for how many time the ISR has been executed

rcall CLK

ldi YL, low(stack_init)    ;Load 0xFF to YL
sts CPU_SPL, YL			   ;transfer to CPU_SPL
ldi YL, high(stack_init)   ;Load 0x3F to YH
sts CPU_SPH, YL			   ;transfer to CPU_SPH

ldi r16, 0x70
sts PORTD_DIRSET, r16    ;set the RGB LED to be output
sts PORTD_OUT, r16       ;turn the RGB LED off

ldi r16, 0b00000111   ; remap the RGB LED
sts PORTD_REMAP, r16  

ldi r16, 0xFF           ;RGB color for 0-255
sts TCD0_PER, r16
ldi r16, 0x00
sts TCD0_PER+1, r16

ldi r16, 0b00000111   ;Timer clock for clk/1024
sts TCD0_CTRLA, r16 

ldi r16, 0b01110011    ; enablc Compare A,B,C. bit 2-0 is single-slope PWM
sts TCD0_CTRLB, r16

ldi r16, 0b01000000                     ;invert the signal because they are low-true LED
sts PORTD_PIN6CTRL, r16
sts PORTD_PIN5CTRL, r16
sts PORTD_PIN4CTRL, r16

lpm


rcall DEBOUNCE
rcall BLINK

cpi r17, 8                   ;branch if greater than 8          
	brsh OVER







DEBOUNCE:
	push r16
	ldi r16, 0x02         ;enable medium level interrupt for INT0
	sts PORTF_INTCTRL, r16

	ldi r16, 0x04
	sts PORTF_INT0MASK, r16    ;set PF2 (tactile switch S1) as the source for INT0

	sts PORTF_DIRCLR, r16    ;set PF2 (tactile switch S1) as input

	ldi r16, 0b00000010     ; the last 3 bits "010" corresponds to falling edge sense trigger
	sts PORTF_PIN2CTRL, r16

	ldi r16, 0x03 
	sts PMIC_CTRL, r16      ;enable low level and medium level interrupt in the PMIC

	sei    ;setting the I bit
	
	pop r16
	ret

BLINK:
	push r16
	ldi r16, low(blink_timer)                    ;set the timer for .1 between blink
	sts TCE0_PER, r16
	ldi r16, high(blink_timer)
	sts TCE0_PER+1, r16

	ldi r16, 0b00000111                           ;Timer clock for clk/1024
	sts TCE0_CTRLA, r16 

	ldi r16, 0x01                                    ;enable low timer interrupt
	sts TCE0_INTCTRLA, r16 
	pop r16
	ret


BLINK_ISR:   ;not finished
	push r18
	lds r18, CPU_SREG
	push r18
	push r16

	cpi r17, 0
	breq RETURN
	cpi r17, 4 
	breq RETURN
	cpi r17, 1
	breq CHECK
	cpi r17, 5
	breq CHECK
	cpi r17, 2
	breq CHECK1
	cpi r17, 6
	breq CHECK1
	cpi r17, 3
	breq CHECK2
	cpi r17, 7
	breq CHECK2

CHECK?
	lpm r16, Z
	cpi r16, 0x9A
	breq INCREMENT
	rjmp DECREMENT

CHECK1:
	lpm r16, Z
	cpi r16, 0x1F
	breq INCREMENT
	rjmp DECREMENT

CHECK2:
	lpm r16, Z
	cpi r16, 0x16
	breq INCREMENT
	rjmp DECREMENT

INCREMENT:
	lpm r16, Z+
	sts TCD0_CCC, r16
	ldi r16, 0x00
	sts TCD0_CCC+1, r16      ;setting the compare value to 0x000E

	lpm r16, Z+
	sts TCD0_CCB, r16
	ldi r16, 0x00
	sts TCD0_CCB+1, r16      ;setting the compare value to 0x000E

	lpm r16, Z+
	sts TCD0_CCA, r16
	ldi r16, 0x00
	sts TCD0_CCA+1, r16      ;setting the compare value to 0x000E

	rjmp RETURN

DECREMENT:
	dec ZL
	lpm r16, Z
	sts TCD0_CCA, r16
	ldi r16, 0x00
	sts TCD0_CCA+1, r16      ;setting the compare value 
	dec ZL

	lpm r16, Z
	sts TCD0_CCB, r16
	ldi r16, 0x00
	sts TCD0_CCB+1, r16      ;setting the compare value 
	dec ZL

	lpm r16, Z
	sts TCD0_CCC, r16
	ldi r16, 0x00
	sts TCD0_CCC+1, r16      ;setting the compare value to 

	rjmp RETURN

RETURN:
	pop r16
	pop r18
	sts CPU_SREG, r18
	pop r18
	reti

ISR: 
	push r18
	lds r18, CPU_SREG
	push r18
	push r16

	ldi r16, 0x00                                  ;setting the CNT back to zero
	sts TCC0_CNT, r16

	ldi r16, low(debounce_timer)                    ;set the timer for 5ms to debounce
	sts TCC0_PER, r16
	ldi r16, high(debounce_timer)
	sts TCC0_PER+1, r16

	ldi r16, 0b00000111                           ;Timer clock for clk/1024
	sts TCC0_CTRLA, r16 

	ldi r16, 0x02                                    ;enable medium timer interrupt
	sts TCC0_INTCTRLA, r16 

	ldi r16, 0x00                                     ;disable PortF external interrupt
	sts PORTF_INTCTRL, r16
	
	pop r16
	pop r18
	sts CPU_SREG, r18
	pop r18
	reti

TIMER_ISR:
	push r18
	lds r18, CPU_SREG
	push r18
	push r16

	ldi r16, 0x00                           ;disable timer
	sts TCC0_CTRLA, r16 

	ldi r16, 0x00
	sts TCC0_INTCTRLA, r16					;disable timer interrupt

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
	sts CPU_SREG, r18
	pop r18
	reti




CLK:   ;take in a r23 value for prescaler. 32MHZ = 0x00 for prescale
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