;; reset.asm

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
  sta nametable
  sta sourceLow
  sta sourceHigh
  
  sta sleep_flag
  sta draw_flag

  sta frame_count_down
  sta frame_count_up
  sta random_return

  sta obj_y
  sta obj_x

  jsr sound_engine_init ; initialize the sound engine

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

InitializeNametables: ; initialize our nametables with our starting background
  lda #$01
  sta nametable
  lda #$00
  sta scroll
  sta columnNumber
.loop:
  jsr DrawNewColumn ; draw bg column
  lda scroll ; get column
  clc 
  adc #$08 
  sta scroll  ; add 8 to scroll
  inc columnNumber  ; increment the column number by 1
  lda columnNumber  ; load column number
  cmp #$20 
  bne .loop ; loop 32 times

  lda #$00
  sta nametable
  sta scroll 
  jsr DrawNewColumn ; draw first column of second nametable
  inc columnNumber

  lda #$00  ; set PPU back to increment +1 mode
  sta $2000
.done:

  ; now, fill our attribute tables
FillAttribute1:
  lda $2002 ; reset the latch
  lda #$23  ; store #$23C0 in address $2006
  sta $2006
  lda #$c0 
  sta $2006
  ldx #$40 ; 64 bytes
  lda #$00
.loop:
  sta $2007
  dex
  bne .loop

FillAttribute2:
  ; the next attribute table goes to #$27C0 in address $2006
  lda $2002
  lda #$27
  sta $2006
  lda #$c0 
  sta $2006
  ldx #$40
  lda #$00 
.loop:
  sta $2007
  dex 
  bne .loop

PPU_Init:
  ;; Finish up our initialization -- begin rendering graphics and enable sound
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 1
  STA $2000
  ; lda #%00010000 ; enable sprites only
  LDA #%00011110   ; enable sprites, background, no clipping on left side
  STA $2001

  jmp main_loop

  ;;;;; wait for vblank ;;;;; 

vblankwait:	; subroutine for PPU initialization
  BIT $2002
  BPL vblankwait
  RTS