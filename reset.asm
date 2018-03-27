;; reset.asm

reset:

RESET:
  SEI		    ;disable IRQ
  CLD		    ;disable decimal mode
  LDX #$40
  STX $4017	;disable APU frame IRQ
  LDX #$FF
  TXS		    ;set up the stack
  INX		    ;now x = 0 (wrapped back around) so we don't need to STX for clrmem
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

PlayerVariablesInit:
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
  ; set collide flag to off
  STA collide_flag 

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

  jsr sound_engine_init ; initialize the sound engine

PPU_Init:
  ;; Finish up our initialization -- begin rendering graphics and enable sound
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 1
  STA $2000
  LDA #%00010000   ; enable sprites
  STA $2001

  rts 