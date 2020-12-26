;
; TrafficSignalSIM.asm
;
; Created: 12/1/2020 5:04:00 PM
; Author : William Angola
; Purpose: Final Project using auto-sequenced timings of LED's to simulate 
;          a Traffic Signal which is interrupted by a push-button
;          to speed-up green to red cycle to allow pedantrians to cross.
;------------------------------------------------------------------------------

; Register Place Holders-------------------------------------------------------
.def temp = r16                                             ; used to initialize stack and toggle LED's
.def counter = r17                                          ; default counter
.def timerCounter = r18                                     ; set timer counter
.def ledState = r19                                         ; current LED state
.def TOGGLEG = r20                                          ; Toggle Green LED
.def TOGGLEY = r21                                          ; Toggle Yellow LED
.def TOGGLER = r22                                          ; Toggle Red LED
;------------------------------------------------------------------------------

; LED const States-------------------------------------------------------------
.equ Green = 0
.equ Yellow = 1
.equ Red = 2
;------------------------------------------------------------------------------

; Constants--------------------------------------------------------------------

; Button
.equ B1_DIR = DDRD            ; Button1 Direction
.equ B1_OUT = PORTD           ; Button1 Portd
.equ B1_IN = PIND             ; Button1 Pind
.equ B1_PIN = PD3             ; Button1 Pin

; LED's
.equ LED_DIR = DDRB           ; LED Direction
.equ LED_OUT = PORTB          ; LED Portd

.equ LEDG_PIN = PB1           ; LED Green Pin

.equ LEDY_PIN = PB2           ; LED Yellow Pin

.equ LEDR_PIN = PB3           ; LED Red Pin
;------------------------------------------------------------------------------

; Configure interrupt vector table---------------------------------------------
.org 0x0000                                                 ; reset
          rjmp      main

.org OC1Aaddr                                               ; timer1 CTC mode interrupt A
          rjmp      oc1a_isr           

.org INT1addr                                               ; External Interrupt Request 1 (PD3)
          rjmp      ext1_isr	


.org INT_VECTORS_SIZE                                       ; end of vector table
;------------------------------------------------------------------------------


;NOTES-------------------------------------------------------------------------
; 1 sec (15624 - 1024 prescaler) CTC MODE
; 3 sec (46874 - 1024 prescaler) CTC MODE
; 4 sec (64299 - 1024 prescaler) CTC MODE

; 1 sec (49911 - 1020 prescaler) Normal MODE
;NOTES-------------------------------------------------------------------------


; Beging Program---------------------------------------------------------------
main:
; Sets up basic structure of program to be in an endless loop every second
; for the compare match A cycle.
;------------------------------------------------------------------------------
          ;initialize stack
          ldi       temp, HIGH(RAMEND)
          out       SPH, temp
          ldi       temp, LOW(RAMEND)
          out       SPL, temp

          ; initialize port registers   
          cbi       B1_DIR, B1_PIN                          ; Set direction for port-d pin-3 to input
          sbi       B1_OUT, B1_PIN                          ; Set pull-up

          sbi       LED_DIR,  LEDG_PIN                      ; set direction for port-b pin-1 to output

          sbi       LED_DIR,  LEDY_PIN                      ; set direction for port-b pin-2 to output

          sbi       LED_DIR,  LEDR_PIN                      ; set direction for port-b pin-3 to output
   

          ; toggle mask for LED states
          ldi       TOGGLEG,(1<<LEDG_PIN)                   ; toggle for LED Green (PB1)
          ldi       TOGGLEY,(1<<LEDY_PIN)                   ; toggle for LED Yellow (PB2)
          ldi       TOGGLER,(1<<LEDR_PIN)                   ; toggle for LED Red (PB3)   

          ; cofigure interrupt for push button
          ldi       r23, (1<< INT1)                         ; enable interrupt 1
          out       EIMSK, r23

          ; configure interrupt sense control bits
          ldi       r23, (1<< ISC01)                        ; set falling edge
          sts       EICRA, r23                              ; interrupt sense control bits

          ; Begin Traffic Light with Green light
          sbi       LED_OUT, LEDG_PIN                      ; Turn LED Green ON

          ; Set default lights
          ldi       ledState, Green                         ; Default ledState to Green
          ldi       counter, 0                              ; Sets counter to 0

          ; Configure Timer1 for 1s

          ; 1) Set counter to 0
          clr       r23
          sts       TCNT1H, r23                             ; clear -> temp
          sts       TCNT1L, r23                             ; clear 1L and temp -> 1H   

          ; 1.1) set 3s delay in output compare register
          ldi       r23, HIGH(15624)                        ; 1s/ (1/16MHZ/1024)) = 15625-1
          sts       OCR1AH, r23                             ; load high byte
          ldi       r23, LOW(15624)
          sts       OCR1AL, r23                             ; and low byte

          ; 2) set mode in timer counter control register A
          clr       r23
          sts       TCCR1A, r23                             ; ctc mode (0<WGM11)|(0<<WGM10)

          ; 3) Set mode and clock select int imer counter control register B
          ldi       r23, (1<<WGM12)|(1<<CS12)|(1<<CS10)
          sts       TCCR1B, r23                             ; ctc mode & 1024 prescaler

          ; 4) set ctc A interrupt in timer interrupt mask register
          ldi       r23, (1<<OCIE1A)
          sts       TIMSK1, r23

          ; Enable global interrupts
          sei

          ; endless loop. Rest of the program is handled by interrupts

end_main: rjmp      end_main
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
oc1a_isr:
; interrupt service routine for timer 1
; using ctc mode for compare match A
;------------------------------------------------------------------------------
 
          call      get_normalCounter                       ; get current normal array index according to ledState                      

          inc       counter                                 ; counter++
          
          cp        counter, timerCounter                   ; if (counter == timerCounter)
          brne      toggle_mismatch                         ;     led_toggle
          call      led_toggle                              ;

; Label Occurs if counter != timerCounter continue to loop          
toggle_mismatch:                                            

          reti                                              ; return interrupt, end oc1a_isr
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
ext1_isr:
; interrupt service routine for external
; interrupt 1 (PD3) when external button
; pushed
;------------------------------------------------------------------------------

          sbic      LED_OUT, LEDR_PIN                       ; If LED Red is on return to normal cycle
          reti                                              ; return from interrupt

          sbic      LED_OUT, LEDY_PIN                       ; If LED Yellow is on return to normal cycle
          reti                                              ; return from interrupt

          ; Set default lights (to begin fast mode)
          ldi       ledState, Green                         ; Default ledState to Green
          ldi       counter, 0                              ; Set counter to 0

fast_loop:
          call      get_fastCounter                         ; get current fast array index according to ledState         

          inc       counter                                 ; counter++
          
          cp        counter, timerCounter                   ; if (counter == timerCounter)
          brne      toggle_mismatchFast                     ;     led_toggle
          call      led_toggle                              ;

          cpi       ledState, Green                         ; if (ledState == Green)
          breq      return_normal                           ;    return to normal cycle 
                                                            ; (Side note: since it turned green again cycle is complete)                                                                                                                                                                            

; Label Occurs if counter != timerCounter continue to loop          
toggle_mismatchFast:                                            

          call      timer1_1s                               ; 1 second delay with normal mode
          rjmp      fast_loop                               ; jump back to fast_loop
          
return_normal:
          call      timer1_regular_reset                    ; Once fast cycle is complete a reset on compare match A 
                                                            ; needs to occur to return to regular cycle.                                            
          reti                                              ; return to normal loop
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
get_normalCounter:
; Get current normal array index according to ledState
;------------------------------------------------------------------------------
          ; set array pointer                               <- b      <- 0
          ldi       ZH,HIGH(normal << 1)                    ; 0 0b00110010
          ldi       ZL,LOW(normal << 1)

          add       ZL, ledState                            ; add ledState to r30 (ZL)
          clr       r0                                      ; clear r0
          adc       ZH, r0                                  ; add with carry r0 to r31 (ZH)

          lpm       timerCounter, Z                         ; Load timerCounter with current 
                                                            ; array index
                                                                                                     
          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
get_fastCounter:

          ; set array pointer                               <- b      <- 0
          ldi       ZH,HIGH(fast << 1)                      ; 0 0b00110010
          ldi       ZL,LOW(fast << 1)

          add       ZL, ledState                            ; add ledState to r30 (ZL)
          clr       r0                                      ; clear r0
          adc       ZH, r0                                  ; add with carry r0 to r31 (ZH)

          lpm       timerCounter, Z                         ; Load timerCounter with current 
                                                            ; array index
                                                                                                     
          ret                                               ; return
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
led_toggle:
; Checks current ledState toggling any LED's that match and increments to 
; toggle the next LED that matches
;------------------------------------------------------------------------------
          
          clr       counter                                 ; clear counter for new index

          ; Toggle current LED then increment and Toggle Next LED

          ; Toggle LED
          cpi       ledState, Green                         ; if (ledState == 0)
          brne      check_Yellow                            ;   toggle Green     
          call      toggle_Green

check_Yellow:

          cpi       ledState, Yellow                        ; if (ledState == 1)
          brne      check_Red                               ;   toggle Yellow
          call      toggle_Yellow

check_Red:

          cpi       ledState, Red                           ; if (ledState == 2)
          brne      check_state                             ;    toggle Red
          call      toggle_Red

check_state:     
   
          cpi       ledState, Red                           ; if(ledState == 2)                                
          brne      increment_state                         ;   reset state and continue toggle               
          call      reset_state                             ; if (ledState != 2)
          rjmp      continue_toggle                         ;   increment_state

increment_state:
          inc       ledState                                ; increment state to change LED color

continue_toggle:
          ; Toggle LED
          cpi       ledState, Green                         ; if (ledState == 0)
          brne      check_Yellow_Again                      ;   toggle Green     
          call      toggle_Green

check_Yellow_Again:

          cpi       ledState, Yellow                        ; if (ledState == 1)
          brne      check_Red_Again                         ;   toggle Yellow
          call      toggle_Yellow

check_Red_Again:

          cpi       ledState, Red                           ; if (ledState == 2)
          brne      Exit_Toggle                             ;    toggle Red
          call      toggle_Red

Exit_Toggle:

          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
timer1_1s:
; 1000ms timer (Normal mode) called in ext1_isr
;------------------------------------------------------------------------------
          ; 1) Set count in TCNT1H/L
          ldi      r23, HIGH(49911)                         ; set timer clock high byte count
          sts      TCNT1H, r23                              ; copy to temp register
          ldi      r23, LOW(49911)                          ; set timer clock low byte count
          sts      TCNT1L, r23                              ; write to low byte and copy temp to high
                                                            ; NOTE: (it must be done in high to low order)

          ; 2) Set mode in TCCR1A
          clr       r23
          sts       TCCR1A, r23                             ; set normal mode

          ; 3) Set clock select in TCCR1B
          ldi       r23, (1<<CS12 | 1 <<CS10)               ; left shift converts hex needed
          sts       TCCR1B, r23                             ; set clk/1024

          ; 4) Watch for TOV1 in TIFR1
tov1_lp:  sbis      TIFR1, TOV1                             ; do {
          rjmp      tov1_lp                                 ; } while (TOV1 == 0)

          ; 5) Stop timer in TCCR1B
          clr       r23
          sts       TCCR1B, r23                             ; set no clock select (turn off timer)

          ; 6) Write 1 to TOV0 in TIFR0                     (write a 1 to the register to clear)
          ldi       r23, (1<<TOV1)
          out       TIFR1, r23                              ; clear TOV1 flag

          ret                                               ; end timer1_1s  
;------------------------------------------------------------------------------


;------------------------------------------------------------------------------
reset_state:
; Reset LED state to avoid usage of incorrect index
;------------------------------------------------------------------------------

          ldi       ledState, Green                         ; Default LED to Green

          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
toggle_Green:
; Toggle Green LED
;------------------------------------------------------------------------------
          in        temp, LED_OUT
          eor       temp, TOGGLEG
          out       LED_OUT, temp

          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
toggle_Yellow:
; Toggle Yellow LED
;------------------------------------------------------------------------------
          in        temp, LED_OUT
          eor       temp, TOGGLEY
          out       LED_OUT, temp

          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
toggle_Red:
; Toggle Red LED
;------------------------------------------------------------------------------
          in        temp, LED_OUT
          eor       temp, TOGGLER
          out       LED_OUT, temp

          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
timer1_regular_reset:
; Reset timer1 before returning to regular loop to continue normal cycle
;------------------------------------------------------------------------------
          ; 1) Set counter to 0
          clr       r23
          sts       TCNT1H, r23                             ; clear -> temp
          sts       TCNT1L, r23                             ; clear 1L and temp -> 1H   

          ; 1.1) set 3s delay in output compare register
          ldi       r23, HIGH(15624)                        ; 1s/ (1/16MHZ/1024)) = 15625-1
          sts       OCR1AH, r23                             ; load high byte
          ldi       r23, LOW(15624)
          sts       OCR1AL, r23                             ; and low byte

          ; 2) set mode in timer counter control register A
          clr       r23
          sts       TCCR1A, r23                             ; ctc mode (0<WGM11)|(0<<WGM10)

          ; 3) Set mode and clock select int imer counter control register B
          ldi       r23, (1<<WGM12)|(1<<CS12)|(1<<CS10)
          sts       TCCR1B, r23                             ; ctc mode & 1024 prescaler

          ; 4) set ctc A interrupt in timer interrupt mask register
          ldi       r23, (1<<OCIE1A)
          sts       TIMSK1, r23
          
          ret                                               ; return
;------------------------------------------------------------------------------

;------------------------------------------------------------------------------
; Arrays
; normal {6,2,4},         (normal cycle - 12 seconds)     (Standard busy road)
; slow {A,2,4}, A = 10    (slow cycle - 16 seconds)      (Slow non busy roads)
; fast {4,2,4}            (fast cycle - 10 seconds) (Pedestrian pushes button)
;------------------------------------------------------------------------------
normal: .db $6, $2, $4, $0
slow:   .db $A, $2, $4, $0
fast:   .db $4, $2, $4, $0       