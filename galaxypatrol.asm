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
buttons1	.rs 1	; reserve 1 byte of space for player 1 button variable

;; Some Constants

;; Banks

  .bank 0
  .org $C000
RESET:
  SEI	;disable IRQ
  CLD	;disable decimal mode
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

Forever:
  JMP Forever

NMI:
  LDA #$00
  STA $2003
  LDA #$02
  LDA $4014

  ;; PPU CLEANUP
  LDA #%10010000
  STA $2000
  LDA #%00011110
  STA $2001
  LDA #$00
  LDA $2005
  LDA $2005

;;;;; Our Subroutines
;;;;; We want these last -- otherwise, where will the RTS take us to? Some random address
;;;;; So, to avoid a crash, we put it last and make sure we have a JMP instruction above

ReadController1:
  LDA #$01
  STA $4016
  LDA #$00
  STA $4016
  LDX #$08
ReadController1Loop:
  LDA $4016
  LSR A		; bit 0 -> carry flag
  ROL buttons1 ; carry flag -> bit 0 of buttons 1
  DEX		; we could start x at 0 and then compare x to 8, but that requires 1 extra instruction
  BNE ReadController1Loop
  RTS

vblankwait:
  BIT $2002
  BPL vblankwait
  RTS

;;;;; BANK 1 - DATA SECTION

  .bank 1
  .org $E000

palette:
  .db $22,$29,$1A,$0F,  $22,$36,$17,$0F,  $22,$30,$21,$0F,  $22,$27,$17,$0F   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $22,$1C,$15,$14,  $22,$02,$38,$3C   ;;sprite palette

  .org $FFFA
  .dw NMI
  .dw RESET
  .dw 0

;;;;;; BANK 2
  .bank 2
  .org $0000