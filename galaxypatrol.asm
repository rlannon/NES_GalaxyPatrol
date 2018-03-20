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
speedy		.rs 1
speedx		.rs 1

;; Some Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence

RIGHTWALL	= $F4	; We don't want the play to be able to move across like PacMan
LEFTWALL	= $04	; So, we will set boundaries. When the player reaches it, we will stop them

;; Banks

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

;; Background Load Sequence Here

;; Attribute Load Sequence Here

;; Let's set some initial stats here -- speed of the ship in X and Y, and the score
  LDA #$02
  STA speedx

  LDA #$02
  STA speedy

  LDA #$00
  STA score

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

NMI:
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
  JSR UpdatePlayerPosition ;; update player position, we should rewrite to update all sprites...
  RTI			;; return from interrupt, where we will wait for the next one

;;;;; More game engine data

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

  JMP GameEngineDone

;;;;; Our Subroutines
;;;;; We want these last -- otherwise, where will the RTS take us to? Some random address
;;;;; So, to avoid a crash, we put it last and make sure we have a JMP instruction above

;;;;; Check controls and update the player position ;;;;;

UpdatePlayerPosition:	; there may be a better way to do this, but this is what I have thus far
  LDA buttons		; get the button state
  AND #%00000010	; see if it's left
  BEQ MoveLeftDone	; if not, check right (see moveLeftDone)
  LDX #$00		; else, set x to 0
MoveLeft:
  LDA $0203,X		; load the X position of our char. We will use X to loop so we edit the whole sprite
  SEC			; set the carry flag so we can subtract
  SBC speedx		; subtract 2 -- our speed
  STA $0203,X		; store the result in the player's X position (essentially, update it)
  TXA			; Now we must update X -- increase it so we can edit all sprites for the player
  CLC			; clear carry for addition
  ADC #$04		; add 4 so our next address will be $0207
  TAX			; transfer A to X
  CPX #$10		; if X is not 16 (if we haven't done this 4 times), do again
  BNE MoveLeft
MoveLeftDone:		; now we check to see if the player tried to move right
  LDA buttons
  AND #%00000001
  BEQ MoveRightDone
  LDX #$00
MoveRight:		; similar procedure as moving left, but we add to X instead of subtracting
  LDA $0203,X
  CLC
  ADC speedx
  STA $0203,X
  TXA
  CLC
  ADC #$04
  TAX
  CPX #$10
  BNE MoveRight
MoveRightDone:		; now we check to see if the player pressed enter
  LDA buttons
  AND #%00010000
  BEQ StartDone
  LDX #$00
StartAndPause:		; currently, this code is just to test that we can get to our pause state
  LDA $0200,X
  CLC
  ADC speedy
  STA $0200,X
  TXA
  CLC
  ADC #$04
  TAX
  CPX #$10
  BNE StartAndPause
StartDone:		; finally, now that all of our controls have been tested, let's return
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