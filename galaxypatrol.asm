;*******************************************;
;*************  GALAXY PATROL  *************;
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
speedy		.rs 1 ; player's speed in the y direction
speedx		.rs 1 ; object's speed in the x direction
scroll    .rs 1
nametable .rs 1

;; Some Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence

TOPWALL = $0A
BOTTOMWALL = $D8

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
  LDA $2002
  LDA #$20
  STA $2006
  LDA #$00
  STA $2006
  LDX #$00
  LDY #$00
LoadBackgroundLoop:
  LDA background, x
  STA $2007
  INX
  CPX #$80
  BNE LoadBackgroundLoop
  INY
  LDX #$00
  CPY #$08
  BNE LoadBackgroundLoop

LoadAttribute:
  LDA $2002
  LDA #$23
  STA $2006
  LDA #$C0
  STA $2006
  LDX #$80
  LDA #$00
LoadAttributeLoop:
  STA $2007
  DEX
  BNE LoadAttributeLoop

;; Let's set some initial stats here
  ;object speed
  LDA #$01
  STA speedx

  ;player speed
  LDA #$02
  STA speedy

  ; initial score
  LDA #$00
  STA score

  ; player position
  LDA #$80
  STA playerY
  LDA #$10
  STA playerX ; not gonna change this

  ;; Set starting game state
  LDA #STATEPLAYING
  STA gamestate
  LDA #$00
  STA scroll
  lda #$00
  sta nametable
  ;; Finish up our initialization -- begin rendering graphics
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 1
  STA $2000
  LDA #%00010000   ; enable sprites
  STA $2001

MainGameLoop:

  JMP MainGameLoop

NMI:              ; This interrupt routine will be called every time VBlank begins
  INC scroll

NTSwapCheck:
  lda scroll
  cmp #$00
  bne NTSwapCheckDone

NTSwap:
  lda nametable ; 0 or 1
  eor #$01
  sta nametable

NTSwapCheckDone:
  LDA #$00
  STA $2003       ; Write zero to the OAM register because we want to use DMA
  LDA #$02
  STA $4014       ; Write to OAM using DMA -- copies bytes at $0200 to OAM

  ;; graphics updating code here?

  LDA #$00
  STA $2006
  STA $2006

  lda scroll
  sta $2005

  lda #$00
  sta $2005

  ;;This is the PPU clean up section, so rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ora nametable
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001
  ; LDA #$00        ;;tell the ppu there is no background scrolling
  ; STA $2005
  ; STA $2005

  JSR ReadController1
  JSR GameEngine

  RTI

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
  RTS

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

  ;; First, let's do MoveDown
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

  JMP GameEngineDone

;;;;;     Our Subroutines   ;;;;;

;;; Update our sprite positions ;;;

UpdateSprites:
  ;; Update player position...this might not be the best way, but it works for now at least
  LDA playerY
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020C

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

  .org $FFFA
  .dw NMI

  .dw RESET

  .dw 0

;;;;;; BANK 2 - GRAPHICS INCLUDE ;;;;;

  .bank 2
  .org $0000
  .incbin "NewFile.chr"	; custom graphics file