;*******************************************;
;*************  GALAXY PATROL  *************;
;*****   Copyright 2018 Riley Lannon   *****;
;*******************************************;

; iNES header
  .inesprg 2  ; 2x 16kb program memory
  .ineschr 1  ; 8kb CHR Data
  .inesmap 0  ; no mapping
  .inesmir 1  ; background mirroring -- vertical mirroring = horizontal scrolling

;---------------------------------------------------
;; Some Variables
  .rsset $0000 ; start variables from RAM location 0

gamestate         	.rs 1	; .rs 1 means reserve 1 byte of space
buttons	          	.rs 1
score           		.rs 1
scroll              .rs 1
nametable           .rs 1

playerX	          	.rs 1
playerY	           	.rs 1
speedy	          	.rs 1 ; player's speed in the y direction
speedx		          .rs 1 ; object's speed in the x direction
obj_y               .rs 1 ; used to count the object's y position
num_objects         .rs 1 ; used to count the number of objects to be generated

collide_flag        .rs 1 ; 1 = asteroid; 2 = fuel
sleep_flag          .rs 1
draw_flag           .rs 1

frame_count_down    .rs 1 ; used to count the number of frames passed since last pressed up/down
frame_count_up      .rs 2

random_return       .rs 1

;---------------------------------------------------
;; Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence
STATEPAUSE  = $03 ; we are in pause

TOPWALL = $0A
BOTTOMWALL = $D8
LEFTWALL = $04
RIGHTWALL = $F4

BUTTON_A = %10000000
BUTTON_B = %01000000
BUTTON_SELECT = %00100000
BUTTON_START = %00010000
BUTTON_UP = %00001000
BUTTON_DOWN = %00000100
BUTTON_LEFT = %00000010
BUTTON_RIGHT = %00000001

;---------------------------------------------------
;; Our first 8kb bank. Include the sound engine here
  .bank 0
  .org $8000

  .include "sound_engine.asm"

;---------------------------------------------------
;; Second 8kb bank
  .bank 1
  .org $A000

;---------------------------------------------------
;; Third 8kb bank

  .bank 2
  .org $C000

  .include "reset.asm"

  jsr reset ; put this in a separate file for code that is easier to read

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;  Main Game Loop  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main_loop:
  ; code here does not execute. Figure this out later.
;   inc sleep_flag 
; .loop:
;   lda sleep_flag
;   bne .loop 

;   jsr gen_random 
  jmp main_loop 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;      NMI     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NMI:      ; This interrupt routine will be called every time VBlank begins
  php     ; begin by pushing all register values to the stack
  pha
  txa
  pha
  tya
  pha

  INC scroll
  
NTSwapCheck:      ; checks to see if we have scrolled all the way to the second nametable
  lda scroll
  bne NTSwapCheckDone

NTSwap:           ; if we have scrolled all the way to the second, display the second, not first
  lda nametable ; 0 or 1
  eor #$01
  sta nametable

NTSwapCheckDone:  ; done with our scroll logic, time to actually draw the graphics
  LDA #$00
  STA $2003       ; Write zero to the OAM register because we want to use DMA
  LDA #$02
  STA $4014       ; Write to OAM using DMA -- copies bytes at $0200 to OAM

  ;jsr sound_play_frame  ; play sound

  ; Clear PPU address register
  LDA #$00
  STA $2006
  STA $2006

  ; scroll the screen
  lda scroll
  sta $2005
  lda #$00
  sta $2005

  ;; PPU clean-up; ensure rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ora nametable
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

  jsr ReadController
  jsr GameEngine

  lda #$00
  sta sleep_flag

  inc frame_count_down  ; increment the number of frames that have occurred since last button press
  inc frame_count_up

  pla
  tay
  pla
  tax 
  pla
  plp     ; we pushed them at the beginning, so pull them back in reverse order

  RTI

IRQ:      ; we aren't using IRQ, at least for now
  RTI 

GameEngine:
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle	;; game is displaying Title Screen

  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver	;; game is displaying game over sequence

  LDA gamestate
  CMP #STATEPAUSE
  BEQ EnginePause

  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying	;; game is in the game loop
GameEngineDone:
  JSR UpdateSprites	;; update all sprites once we are done with the game engine
  RTS

;;;;; Our Game Engine Routines

EngineTitle:  ; what do we do on the title screen?
  JMP GameEngineDone	;; Unconditional jump to GameEngineDone so we can continue with the loop

EngineGameOver:
  JMP GameEngineDone

EnginePause
  JMP EnginePauseDone
EnginePauseDone:

EnginePlaying:
  ; First, we check to see if we need to handle controllers

PressA: ;show asteroid
  lda buttons
  and #BUTTON_A 
  beq .done 

  lda #$00
  sta $0212
.done:

PressB: ;hide asteroid
  lda buttons 
  and #BUTTON_B
  beq .done

  lda #%00100000
  sta $0212
.done:

PressSelect:
  LDA buttons
  AND #BUTTON_SELECT
  BEQ .done
.done:

PressStart:       ; to test if this works, place an asteroid at randomly generated y position
  LDA buttons
  AND #BUTTON_START
  BEQ .done

  lda draw_flag
  bne .done

  jsr put_y
  lda obj_y
  sta $0210
  lda #$04
  sta $0211
  lda #$00
  sta $0212
  lda #RIGHTWALL
  sta $0213

  inc draw_flag
.done:

MoveUp:
  LDA buttons
  AND #BUTTON_UP
  BEQ .done

  lda draw_flag
  bne .done

  lda #$00
  sta frame_count_up

  LDA playerY		; same logic as MoveRight here
  SEC
  SBC speedy
  STA playerY

  inc draw_flag

  LDA playerY
  CMP #TOPWALL
  BCS .done	    ; must be above or equal to left wall, so carry flag SHOULD be set, not clear
  LDA #TOPWALL
  STA playerY
.done:

MoveDown:
  LDA buttons		; first, check user input -- are they hitting down on D pad?
  AND #BUTTON_DOWN
  BEQ .done   	; if not, we are done

  lda draw_flag
  bne .done

  lda #$00          ; whenever the player hits "down" on the d pad, clear the frame_count variable
  sta frame_count_down

  LDA playerY		; if they are, load the current Y position
  CLC			      ; clear carry
  ADC speedy		; add the y speed to the y position
  STA playerY		; store that in the player y position

  inc draw_flag

  LDA playerY		; now we must check to see if player y > wall
  CMP #BOTTOMWALL	; compare the y position to the right wall. Carry flag set if A >= M
  BCC .done	    ; if it's less than or equal, then we are done (carry flag not set if less than RIGHTWALL)
  LDA #BOTTOMWALL	; otherwise, load the wall value into the accumulator
  STA playerY		; and then set the playerX value equal to the wall
.done:

PressLeft:
  lda buttons
  and #BUTTON_LEFT
  beq .done 

  lda note_move_flag
  bne .done 
  
  dec note_ptr
  lda #$01
  sta note_move_flag
.done:

PressRight:
  lda buttons
  and #BUTTON_RIGHT 
  beq .done

  lda note_move_flag
  bne .done

  inc note_ptr
  lda #$01
  sta note_move_flag
.done:

  ; Next, we need to check for collisions
CheckCollision:
  JMP .done
.done:

  ; generate some random numbers and make assignments
RandomGen:
  jsr gen_random
.done:

  JMP GameEngineDone  ; we are done with the game engine code, so let's go to that label

;;;;;     Our Subroutines   ;;;;;

;;; Update our sprite positions ;;;

UpdateSprites:
  LDA playerY
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020C
  ;; once we add in obstacles like rocks and fuel, we will update them here as well
  ;; those routines will probably simply be decrementing the X position

  ;; move fuel position across screen
  dec $0213
  lda $0213
  cmp #LEFTWALL
  bcs .done ; if sprite has not reached edge of screen, we are done (carry flag not set)
.rem_loop:  ; if the sprite has reached the edge, we need to remove it
  lda #%00100000  ; this puts the sprite behind the background, effectively removing it
  sta $0212
.done:
  lda #$00
  sta draw_flag
  RTS

;;;;; Read Controller Input ;;;;;

ReadController:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadControllerLoop:
  LDA $4016
  LSR A		; bit 0 -> carry flag
  ROL buttons   ; carry flag -> bit 0 of buttons 1
  DEX		; we could start x at 0 and then compare x to 8, but that requires 1 extra instruction
  BNE ReadControllerLoop
  RTS

;;;;; Generate number of objects ;;;;;

;; this PRNG uses a linear feedback shift register

gen_random:             ; generate the number of objects (asteroids/fuel) to be placed on the screen
  ldx frame_count_down  ; we will iterate 8 times
  lda frame_count_up+0  ; load low byte of the number of frames since last down-button press
.loop:
  asl a 
  rol frame_count_up+1  ; load into high byte of 16-bit frame_count
  bcc .done
  eor #$2D              ; apply XOR feedback whenever a 1 is shifted out
.done:
  dex
  bne .loop 
  sta random_return 
  cmp #$0   ; reload flags
  rts 

put_y:      ; subroutine to put our random number in the asteroid's y position
  lda random_return 
  sta obj_y
  rts 

;;;;; wait for vblank ;;;;; 

vblankwait:	; subroutine for PPU initialization
  BIT $2002
  BPL vblankwait
  RTS

;---------------------------------------------------
;; 4th 8kb bank -- Data tables

  .bank 3
  .org $E000
palette:
  .db $30,$00,$10,$0F,  $0F,$36,$17,$22,  $0F,$30,$21,$22,  $0F,$27,$17,$22   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ; player
     ;vert tile attr horiz
  .db $80, $00, $00, $10   ;sprite 0
  .db $80, $01, $00, $18   ;sprite 1
  .db $88, $02, $00, $10
  .db $88, $03, $00, $18
    ; asteroid
  .db $80, $04, $00, $80

background:
  .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  .db $0F, $0E, $0D, $0C, $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00
  .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  .db $0F, $0E, $0D, $0C, $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00
  .db $0F, $0E, $0D, $0C, $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00
  .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F
  .db $0F, $0E, $0D, $0C, $0B, $0A, $09, $08, $07, $06, $05, $04, $03, $02, $01, $00
  .db $00, $01, $02, $03, $04, $05, $06, $07, $08, $09, $0A, $0B, $0C, $0D, $0E, $0F

;---------------------------------------------------
;; Vectors

  .org $FFFA
  .dw NMI

  .dw RESET

  .dw 0

  .bank 4
  .org $0000
  .incbin "NewFile.chr"	; custom graphics file