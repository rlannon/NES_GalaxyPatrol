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
playerX	          	.rs 1
playerY	           	.rs 1
score           		.rs 1
speedy	          	.rs 1 ; player's speed in the y direction
speedx		          .rs 1 ; object's speed in the x direction
scroll              .rs 1
nametable           .rs 1
collide_flag        .rs 1 ; 1 = asteroid; 2 = fuel

;---------------------------------------------------
;; Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence
STATEPAUSE  = $03 ; we are in pause

TOPWALL = $0A
BOTTOMWALL = $D8

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

MainGameLoop:
  ;; put game logic here. Use a "sleep" flag to prevent us from doing too much per frame
  JMP MainGameLoop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;      NMI     ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

NMI:              ; This interrupt routine will be called every time VBlank begins
  ; transfer all registers to the stack -- in case we decide to move game logic later
  pha
  php
  txa
  pha
  tya
  pha

  INC scroll

NTSwapCheck:      ; checks to see if we have scrolled all the way to the second nametable
  lda scroll
  cmp #$00
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

  ; Handle the actual game logic
  JSR ReadController
  JSR GameEngine

  pla
  tay
  pla
  tax 
  plp 
  pla 

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

PressSelect:
  LDA buttons
  AND #%00100000
  BEQ PressSelectDone

  JSR sound_disable 
PressSelectDone:

PressStart:
  LDA buttons
  AND #%00010000
  BEQ PressStartDone

  LDA #%00111000
  STA $4000

  LDA note_ptr ; this makes 1 byte
  ASL A   ; but, we are indexing to a table of words. So, we must multiply by 2 to make the byte into a word
  TAY 
  LDA note_table, y
  STA SQ1_LOW
  LDA note_table+1, y
  STA SQ1_HIGH

  lda #$00
  sta note_move_flag
PressStartDone:

MoveUp:
  LDA buttons
  AND #%00001000
  BEQ MoveUpDone

  LDA playerY		; same logic as MoveRight here
  SEC
  SBC speedy
  STA playerY

  LDA playerY
  CMP #TOPWALL
  BCS MoveUpDone	; must be above or equal to left wall, so carry flag SHOULD be set, not clear
  LDA #TOPWALL
  STA playerY
MoveUpDone:

MoveDown:
  LDA buttons		; first, check user input -- are they hitting down on D pad?
  AND #%00000100
  BEQ MoveDownDone	; if not, we are done

  LDA playerY		; if they are, load the current Y position
  CLC			; clear carry
  ADC speedy		; add the y speed to the y position
  STA playerY		; store that in the player y position

  LDA playerY		; now we must check to see if player y > wall
  CMP #BOTTOMWALL	; compare the y position to the right wall. Carry flag set if A >= M
  BCC MoveDownDone	; if it's less than or equal, then we are done (carry flag not set if less than RIGHTWALL)
  LDA #BOTTOMWALL	; otherwise, load the wall value into the accumulator
  STA playerY		; and then set the playerX value equal to the wall
MoveDownDone:

PressLeft:
  lda buttons
  and #%00000010
  beq PressLeftDone

  lda note_move_flag
  bne PressLeftDone
  
  dec note_ptr
  lda #$01
  sta note_move_flag
PressLeftDone:

PressRight:
  lda buttons
  and #%00000001
  beq PressRightDone

  lda note_move_flag
  bne PressRightDone

  inc note_ptr
  lda #$01
  sta note_move_flag
PressRightDone:

  ; Next, we need to check for collisions
CheckCollision:
  JMP CheckCollisionDone
CheckCollisionDone:

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
  ;; those routines will probably simply be decrementing the Y position
UpdateSpritesDone:
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
     ;vert tile attr horiz
  .db $80, $00, $00, $10   ;sprite 0
  .db $80, $01, $00, $18   ;sprite 1
  .db $88, $02, $00, $10
  .db $88, $03, $00, $18

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