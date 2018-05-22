/* Lab 4 Part E
   Name: Pengzhao Zhu
   Section#: 112D
   TA Name: Chris Crary
   Description: This Program blinks the RGB between two color combination with a .1 blink alternation period
				Four settings in total (4 sets of combination for RGB blink )
				It will also output the number of times S1 is pressed to the 8 LEDs
*/


.include "ATxmega128A1Udef.inc"        ;include the file
.list                                  ;list it 

.org 0x0000                            ;start our program here
rjmp MAIN                              ;jump to main

.org PORTF_INT0_vect       ;for the edge trigger debounce interrupt
	rjmp EDGE_ISR

.org TCC0_OVF_vect       ;for the 5 ms timer debounce interrupt
	rjmp DEBOUNCE_TIMER_ISR

.org TCE0_OVF_vect       ;for the .1 second blink timer interrupt
	rjmp BLINK_ISR

;Have to use TCC0 and TCE0 because PER OF TCD0 is used for PWM

.equ stack_init=0x3FFF   ;initialize stack pointer
.equ debounce_timer= (32000000*.005)/1024      ;.equ for PER of debounce timer ISR
.equ blink_timer =(32000000*.1)/1024			;.equ for PER of blink timer ISR

.org 0x100
Table :.db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00        ;table for no LED light up
Table1:.db 0x9A, 0x2C, 0x8A, 0x07, 0xFF, 0x49		 ;table for INCREDIBLE HULK
Table2:.db 0x1F, 0x1F, 0xC2, 0x0D, 0x8D, 0x3C		 ;table for HOLIDAY 
Table3:.db 0x16, 0x46, 0xFA, 0xA5, 0x21, 0x00		 ;table for UF

.org 0x200

MAIN:
ldi r23, 0x00   ;setting for 32MHZ subroutine. 
ldi r17, 0x00   ;counter register for how many time the ISR has been executed
ldi r22, 0x00   ;bit0, capture D(BLUE). BIT1, capture C(Green). Bit 2, capture (RED)    . 0 means forward, 1 means back 
				;register so I know which data to take
ldi r20, 0x00   ;counter register for the 8 LED
rcall CLK

ldi YL, low(stack_init)    ;Load 0xFF to YL
sts CPU_SPL, YL			   ;transfer to CPU_SPL
ldi YL, high(stack_init)   ;Load 0x3F to YH
sts CPU_SPH, YL			   ;transfer to CPU_SPH

ldi r16, 0xFF              ;just want to see the outputted
sts PORTC_DIRSET, r16    ;set the 8 LED to be output
sts PORTC_OUT, r16       ;turn the 8 active low LED off

rcall DEBOUNCE   ;call subroutine to initialze port edge interrupt
rcall PWM    ;call subroutine to initialize PWM
rcall BLINK  ;call subroutine to set up .1 second switch interrupt

DONE:
	rjmp DONE

PWM:
push r16
ldi r16, 0x70
sts PORTD_DIRSET, r16    ;set the RGB LED to be output
sts PORTD_OUT, r16       ;turn the RGB LED off

ldi r16, 0b00000111   ; remap the RGB LED
sts PORTD_REMAP, r16  

ldi r16, 0xFF           ;load r16
sts TCD0_PER, r16       ;load low byte of PER
ldi r16, 0x00           ;load r16
sts TCD0_PER+1, r16		;load high byte of PER

ldi r16, 0b00000111   ;Timer clock for clk/1024
sts TCD0_CTRLA, r16 

ldi r16, 0b01110011    ; enablc Compare A,B,C. bit 2-0 is single-slope PWM
sts TCD0_CTRLB, r16

ldi r16, 0x00
sts TCD0_CCC, r16                 ;CCC is for blue LED
sts TCD0_CCC+1, r16				;need to load low and high byte

sts TCD0_CCB, r16			;CCB is for Green LED
sts TCD0_CCB+1, r16			;need to load low and high byte

sts TCD0_CCA, r16			;CCA is for Red LED
sts TCD0_CCA+1, r16			;need to load low and high byte

ldi r16, 0b01000000                     ;invert the signal because they are low-true LED
sts PORTD_PIN6CTRL, r16					;invert 3 pins between there are Red, Green, and Blue LED. 3 of them
sts PORTD_PIN5CTRL, r16
sts PORTD_PIN4CTRL, r16

pop r16
ret										;return




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

BLINK:                                       ;initialize the timer/timer interrupt for .1 second blink
push r16
ldi r16, low(blink_timer)                    ;set the timer for .1 between blink
sts TCE0_PER, r16							 ;need to load low and high byte
ldi r16, high(blink_timer)
sts TCE0_PER+1, r16

ldi r16, 0b00000111                           ;Timer clock for clk/1024
sts TCE0_CTRLA, r16 

ldi r16, 0x01                                    ;enable low level timer interrrupt
sts TCE0_INTCTRLA, r16 


pop r16
ret												;return from subroutine

EDGE_ISR:                                        ;initialization for edge interrupt
push r18										;push the necessary registers and status register
lds r18, CPU_SREG
push r18
push r16

ldi r16, 0x00                                  ;setting the CNT back to zero
sts TCC0_CNT, r16

ldi r16, low(debounce_timer)                    ;set the timer for 5ms to debounce
sts TCC0_PER, r16								;need to load low and high byte of PER
ldi r16, high(debounce_timer)
sts TCC0_PER+1, r16

ldi r16, 0b00000111                           ;Timer clock for clk/1024
sts TCC0_CTRLA, r16 

ldi r16, 0x02                                    ;enable medium timer interrupt
sts TCC0_INTCTRLA, r16 

ldi r16, 0x00                                     ;disable PortF external interrupt
sts PORTF_INTCTRL, r16
	
pop r16										;pop the necessary registers. including the status register
pop r18
sts CPU_SREG, r18
pop r18
reti										;return from interrupt

DEBOUNCE_TIMER_ISR:                  ;initialization for the 5ms timer used for debounce
push r18				
lds r18, CPU_SREG					;push the necessary registers and status register
push r18
push r16

ldi r16, 0x00                           ;disable timer
sts TCC0_CTRLA, r16 

ldi r16, 0x00
sts TCC0_INTCTRLA, r16					;disable timer interrupt

lds r16, PORTF_IN       ;to check if switch is still active
bst r16, 2             
brts NOT_ACTIVE             ;if set, it means it is not active
 
inc r17                     ;if active, increment r17. r17 is a counter
							;the rest of separate. the next 4 line of code are for 8 LED count
inc r20             ;to increase r20 by 1 everytime the ISR is executed
com r20             ;takes one's complement of r20 because LED are active low

sts PORTC_OUT, r20			;output the value
com r20             ;takes one's complement again so r20 is correct the next time we execuate the ISR

NOT_ACTIVE:

ldi r16, 0x02                                    ;enable PortF external medium level interrupt
sts PORTF_INTCTRL, r16

ldi r16, 0x01                                    ;clear the interrupt flag
sts PORTF_INTFLAGS, r16


pop r16                                          ;prepare to return from interrupt
pop r18											;pop the necessary registers. including the status register
sts CPU_SREG, r18
pop r18
reti


BLINK_ISR:   
push ZL                              ;pushes the necessary registers. including the status register
push ZH
push r18
lds r18, CPU_SREG
push r18
push r16


	
cpi r17, 0                         ;check the counter for how many times tactile switch S1 is pressed
breq STORE							;Jump to different part of the code depending on r17 value
cpi r17, 1
breq STORE1
cpi r17, 2							;should be self explanatory
breq STORE2
cpi r17, 3
breq STORE3

STORE:                                        ;load corresponding tables
ldi ZL, low(Table<<1)						  ;r17=0, no output
ldi ZH, high(Table<<1)
rjmp CHECK

STORE1:
ldi ZL, low(Table1<<1)					;load corresponding tables
ldi ZH, high(Table1<<1)					;r17=1, INCREDIBLE HULK color
rjmp CHECK

STORE2:
ldi ZL, low(Table2<<1)					;load corresponding tables
ldi ZH, high(Table2<<1)					;r17=2, HOLIDAY color
rjmp CHECK

STORE3:
ldi ZL, low(Table3<<1)					;load corresponding tables
ldi ZH, high(Table3<<1)					;r17=3, UF Color

CHECK:
bst r22, 0							;r22 is just a register so I how which half of the table to load
brtc LOAD                           ;will be inverted everytime
	
adiw ZH:ZL, 3                       ;add 3 to counter for blinking
	
LOAD:
ldi r16, 0x08                       ;force restart of the TC system
sts TCD0_CTRLFSET, r16

lpm r16, Z+                         ;load corresponding table values for each capture
sts TCD0_CCC, r16					;CCC is for blue LED
ldi r16, 0x00						;need to load low and high byte
sts TCD0_CCC+1, r16      

lpm r16, Z+							;load corresponding table values for each capture
sts TCD0_CCB, r16					;CCB is for green LED
ldi r16, 0x00						;need to load low and high byte
sts TCD0_CCB+1, r16      

lpm r16, Z+							;load corresponding table values for each capture
sts TCD0_CCA, r16					;CCA is for red LED
ldi r16, 0x00						;need to load low and high byte
sts TCD0_CCA+1, r16      

com r22  ;take one's complement of r22. so it will load different half of the table set next time

cpi r17, 4							;compare r17 with 4
brsh RESET							;branch if greater or equal to 4
brne SKIP							;otherwise, branch to SKIP
RESET:
ldi r17, 0                           ;when counter half reach 4. start over. load r17=0
	
SKIP:

ldi r16, 0x00                                  ;setting the CNT back to zero
sts TCE0_CNT, r16 

ldi r16, 0x01
sts TCE0_INTFLAGS, r16                         ;clear the interrupt flag

pop r16
pop r18										;pop the necessary register and prepare to return from interrupt
sts CPU_SREG, r18
pop r18
pop ZH
pop ZL
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