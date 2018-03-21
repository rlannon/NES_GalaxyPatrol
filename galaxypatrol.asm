;*******************************************;
;**********     GALAXY PATROL     **********;
;*****   Copyright 2018 Riley Lannon   *****;
;*******************************************;

; iNES header
  .inesprg 1
  .ineschr 1
  .inesmap 0
  .inesmir 1

;; Some Variables
  .rsset $0000 ; start variables from RAM location 0

gamestate	.rs 1	; .rs 1 means reserve 1 byte of space
buttons		.rs 1
playerX		.rs 1
playerY		.rs 1
score		.rs 1
speedy		.rs 1 ; object speed in the y direction
speedx		.rs 1 ; player's speed in the x direction

;; Some Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence

RIGHTWALL	= $F0	; We don't want the play to be able to move across like PacMan
LEFTWALL	= $02	; So, we will set boundaries. When the player reaches it, we will stop them

;; Bank 0

  .bank 0
  .org $C000
RESET:
  SEI		;disable IRQ
  CLD		;disable decimal mode
  LDX #$40
  STX $4017	;disable APU frame IRQ
  LDX #$FF
  TXS		;set up the stack
  INX		;now x = 0
  STX $2000	;disable NMI
  STX $2001	;disable rendering
  STX $4010	;disable DMC IRQs

  JSR vblankwait

clrmem:
  LDA #$00
  STA $0000, x
  STA $0100, x
  STA $0300, x
  STA $0400, x
  STA $0500, x
  STA $0600, x
  STA $0700, x
  LDA #$FE
  STA $0200, x
  INX
  BNE clrmem

  JSR vblankwait

LoadPalettes:
  LDA $2002
  LDA #$3F
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00
LoadPalettesLoop:
  LDA palette, X
  STA $2007
  INX
  CPX #$20
  BNE LoadPalettesLoop

LoadSprites:
  LDX #$00
LoadSpritesLoop:
  LDA sprites, X
  STA $0200, X
  INX
  CPX #$10
  BNE LoadSpritesLoop

LoadBackground:
  LDX #$00
LoadBackgroundLoop:
;; Background Load Sequence Here

LoadAttribute:
  LDX #$00
LoadAttributeLoop:
;; Attribute Load Sequence Here

;; Let's set some initial stats here
  ; initial player speed
  LDA #$02
  STA speedx
  ; initial object speed
  LDA #$01
  STA speedy
  ; initial score
  LDA #$00
  STA score
  ; player position
  LDA #$28    ;; This won't change at all
  STA playerY
  LDA #$80
  STA playerX
  ;; Set starting game state
  LDA #STATEPLAYING
  STA gamestate
  ;; Finish up our initialization -- begin rendering graphics
  LDA #%10000000   ; enable NMI, sprites from Pattern Table 1
  STA $2000
  LDA #%00010000   ; enable sprites
  STA $2001

Forever:
  JMP Forever	; jump back to Forever, waiting for NMI

NMI:              ; This interrupt routine will be called every time VBlank begins
  LDA #$00
  STA $2003
  LDA #$02
  STA $4014

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  LDA #$00        ;;tell the ppu there is no background scrolling
  STA $2005
  STA $2005

  ;; all graphics updates should be done by here
  ;; so, let's read our controller input and go into the "game engine"

  JSR ReadController1

GameEngine:
  LDA gamestate
  CMP #STATETITLE
  BEQ EngineTitle	;; game is displaying Title Screen

  LDA gamestate
  CMP #STATEGAMEOVER
  BEQ EngineGameOver	;; game is displaying game over sequence

  LDA gamestate
  CMP #STATEPLAYING
  BEQ EnginePlaying	;; game is in the game loop
GameEngineDone:
  JSR UpdateSprites	;; update all sprites
  RTI			;; return from interrupt, where we will wait for the next one

;;;;; Our Game Engine Routines

EngineTitle:
  JMP GameEngineDone	;; Unconditional jump to GameEngineDone so we can continue with the loop

EngineGameOver:
  JMP GameEngineDone

EnginePlaying:

  ;; do all movement computation, etc here
  ;; check inputs
  ;; check collisions
  ;; move sprites

  ;; then we have a separate subroutine just to draw the updates?
  ;; We will have some rewriting, but the program flow might make more sense if we do it this way

  ;; First, let's do MoveRight
MoveRight:
  LDA buttons		; first, check user input -- are they hitting right on D pad?
  AND #%00000001
  BEQ MoveRightDone	; if not, we are done

  LDA playerX		; if they are, load the current X position
  CLC			; clear carry
  ADC speedx		; add the x speed to the x position
  STA playerX		; store that in the player x position

  LDA playerX		; now we must check to see if player x > wall
  CMP #RIGHTWALL	; compare the x position to the right wall. Carry flag set if A >= M
  BCC MoveRightDone	; if it's less than or equal, then we are done (carry flag not set if less than RIGHTWALL)
  LDA #RIGHTWALL	; otherwise, load the wall value into the accumulator
  STA playerX		; and then set the playerX value equal to the wall
MoveRightDone:

MoveLeft:
  LDA buttons
  AND #%00000010
  BEQ MoveLeftDone

  LDA playerX		; same logic as MoveRight here
  SEC
  SBC speedx
  STA playerX

  LDA playerX
  CMP #LEFTWALL
  BCS MoveLeftDone	; must be above or equal to left wall, so carry flag SHOULD be set, not clear
  LDA #LEFTWALL
  STA playerX
MoveLeftDone:

  JMP GameEngineDone

;;;;;     Our Subroutines   ;;;;;

;;; Update our sprite positions ;;;

UpdateSprites:
  ;; Update player position...this might not be the best way, but it works for now at least
  LDA playerX
  STA $0203
  STA $020B
  CLC
  ADC #$08
  STA $0207
  STA $020F

  ;; once we add in obstacles like rocks and fuel, we will update them here as well
  ;; those routines will probably simply be decrementing the Y position

  RTS

;;;;; Read Controller Input ;;;;;

ReadController1:	; since this is a single player game, we could rename this "ReadController"
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A		; bit 0 -> carry flag
  ROL buttons   ; carry flag -> bit 0 of buttons 1
  DEX		; we could start x at 0 and then compare x to 8, but that requires 1 extra instruction
  BNE ReadController1Loop
  RTS

vblankwait:	; subroutine for PPU initialization
  BIT $2002
  BPL vblankwait
  RTS

;;;;; BANK 1 - DATA SECTION ;;;;;

  .bank 1
  .org $E000
palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

sprites:
     ;vert tile attr horiz
  .db $20, $00, $00, $80   ;sprite 0
  .db $20, $01, $00, $88   ;sprite 1
  .db $28, $02, $00, $80
  .db $28, $03, $00, $88

  .org $FFFA
  .dw NMI

  .dw RESET

  .dw 0

;;;;;; BANK 2 - GRAPHICS INCLUDE ;;;;;

  .bank 2
  .org $0000
  .incbin "NewFile.chr"	; custom graphics file