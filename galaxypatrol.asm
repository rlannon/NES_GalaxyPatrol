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

columnLow           .rs 1 ; low byte of column address
columnHigh          .rs 1 ; high byte of column address
columnNumber        .rs 1
sourceLow           .rs 1
sourceHigh          .rs 1

buff_ptr = $fe
buff_ptr_2 = $ff
buff_data_p = $fc ; this is only used when writing to the graphics buffer
buff_data_p2 = $fd ; it allows us to load the correct value from the data source but store it to the correct address

playerX	          	.rs 1
playerY	           	.rs 1
speedy	          	.rs 1 ; player's speed in the y direction
speedx		          .rs 1 ; object's speed in the x direction
asteroid_y          .rs 1 ; used to count the asteroid's y position
fuel_x              .rs 1 ; used to track the fuel object (limit per nametable?)
fuel_y              .rs 1
num_objects         .rs 1 ; used to count the number of objects to be generated

collide_flag        .rs 1 ; 1 = asteroid; 2 = fuel ?
sleep_flag          .rs 1
draw_flag           .rs 1
sprite_draw_flag    .rs 1 ; used in the game engine to determine whether we should update sprite positions

frame_count_down    .rs 2 ; used to count the number of frames passed since last pressed up/down
frame_count_up      .rs 2

random_return       .rs 1

;---------------------------------------------------
;; Constants
STATETITLE	= $00	; Displaying title screen
STATEPLAYING	= $01	; playing the game; draw graphics, check paddles, etc.
STATEGAMEOVER	= $02	; game over sequence
STATEPAUSE  = $03 ; we are in pause

; define our window limits
TOPWALL = $0A
BOTTOMWALL = $D8
LEFTWALL = $04
RIGHTWALL = $F4

; constants for button presses so we don't have to write out binary every time
BUTTON_A = %10000000
BUTTON_B = %01000000
BUTTON_SELECT = %00100000
BUTTON_START = %00010000
BUTTON_UP = %00001000
BUTTON_DOWN = %00000100
BUTTON_LEFT = %00000010
BUTTON_RIGHT = %00000001

; Our memory buffer is located between $0400 and $07FF

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

  ; RESET goes here -- points to $C000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;  Main Game Loop  ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

main_loop: 
  ; our main game loop
.loop:
  lda sleep_flag
  bne .loop

  jsr ReadController
  jsr GameEngine

  inc sleep_flag

  jsr DrawRoutine

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

  inc scroll

NTSwapCheck:      ; checks to see if we have scrolled all the way to the second nametable
  lda scroll
  bne NTSwapCheckDone

NTSwap:           ; if we have scrolled all the way to the second, display second nametable
  lda nametable ; 0 or 1
  eor #$01
  sta nametable    ; without this, background will immediately revert to the first nametable upon scrolling all the way across
  ; basically, if we are at 0, we switch to 1, and if we are at 1, we switch to 0

NTSwapCheckDone:  ; done with our scroll logic, time to actually draw the graphics

  lda draw_flag
  beq BufferTransferDone
  ; this gets executed in the event that draw_flag is set

  ldy #$00
  lda [buff_ptr], y ; $0400 - number of bytes
  tax ; now X should be equal to 1E
  cpx #$00
  beq BufferTransferDone ; if x is 0, abort drawing because there is no new data in the buffer
  iny
  lda $2002
  lda [buff_ptr], y ; $0401 - contains columnHigh
  sta $2006
  iny
  lda [buff_ptr], y ; $0402 - contains columnLow
  sta $2006
  iny 
  lda [buff_ptr], y ; $0403 - should be our +32 mode
  sta $2000
  iny
BufferTransferLoop:
  lda [buff_ptr], y ; $0404 - x
  sta $2007
  iny
  dex
  bne BufferTransferLoop
BufferTransferDone:
  LDA #$00
  sta draw_flag   ; clear the draw flag
  STA $2000       ; put PPU back to +1 mode

  STA $2003       ; Write zero to the OAM register because we want to use DMA
  LDA #$02
  STA $4014       ; Write to OAM using DMA -- copies bytes at $0200 to OAM

  ;jsr sound_play_frame  ; play sound

  ; Clear PPU address register
  lda $2002
  LDA #$00
  STA $2006
  STA $2006

  ; scroll the screen
  lda $2002   ; reading PPUSTATUS resets the address latch

  lda scroll
  sta $2005   ; $2005 is the PPUSCROLL register; high byte is X scroll

  lda #$00
  sta $2005   ; low byte is Y scroll

  ;; PPU clean-up; ensure rendering the next frame starts properly.
  LDA #%10010000   ; enable NMI, sprites from Pattern Table 0, background from Pattern Table 1
  ora nametable
  STA $2000
  LDA #%00011110   ; enable sprites, enable background, no clipping on left side
  STA $2001

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;      GAME LOGIC     ;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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

EnginePause:          ; create a "pause" screen here
  ;; This causes all sorts of weird shit to happen

  jsr ReadController  ; get controller input

  lda buttons
  and #BUTTON_START   ; if the user presses "START", then go back to playing
  beq .done

  lda #STATEPLAYING 
  sta gamestate
.done:
  jmp GameEngineDone

EnginePlaying:
  ; First, we check to see if we need to handle controllers

PressA:
  lda buttons
  and #BUTTON_A 
  beq .done

  lda draw_flag
  bne .done

  lda num_objects
  eor #$01
  sta num_objects 
.done:

PressB:
  lda buttons 
  and #BUTTON_B
  beq .done

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

  lda #STATEPAUSE
  sta gamestate
  jmp GameEngineDone
.done:

MoveUp:
  LDA buttons
  AND #BUTTON_UP
  BEQ .done

  lda sprite_draw_flag
  bne .done

  lda #$00
  sta frame_count_up

  LDA playerY		; same logic as MoveRight here
  SEC
  SBC speedy
  STA playerY

  inc sprite_draw_flag

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

  lda sprite_draw_flag
  bne .done

  lda #$00          ; whenever the player hits "down" on the d pad, clear the frame_count variable
  sta frame_count_down  ; should we try to use a 16 bit number as seed?

  LDA playerY		; if they are, load the current Y position
  CLC			      ; clear carry
  ADC speedy		; add the y speed to the y position
  STA playerY		; store that in the player y position

  inc sprite_draw_flag

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
  ; We do two things in this routine -- 
  ; 1) check for a collision against a background object;
  ; 2) check for a collision with a sprite
  ; This will determine how we resolve the collision
.bkg_chk: ; check for background collision by reading the background value around the player
  ; the reason we would want the whole field of view in the buffer is for checking this...
  ; because it's currently not all stored in the buffer, we need to get the data during vblank...
.sprite_chk:  ; check for sprite collision by checking the fuel's edges against the player's
  ; this uses the following formula; all numbers must be unsigned:
  ; if ((num - lower) <= (upper - lower)) then in_range(num)
.s_y1:
  lda fuel_y  ; top left corner of fuel
  sec 
  sbc playerY ; subtract top left corner of player position
  cmp #$11  ; check to see if the result is in the desired range of 16 px
  bcs .s_y2 ; the carry will only be set if A >= 17, but A must be <= 16 in order for it to be in range
  jmp .s_x1 ; if the number was in range, then we will check for an x-axis collision
.s_y2:  ; if number was not in range, check the other end of the fuel sprite
  lda fuel_y ; same procedure as before, except we check for fuel+8 instead of fuel
  clc 
  adc #$08
  sec 
  sbc playerY
  cmp #$11  ; note how it must be <= 16...so we just compare to 17, and we get the correct result
  bcs .done 
.s_x1:
  lda fuel_x  ; same procedure for x as for y
  sec 
  sbc playerX 
  cmp #$11
  bcs .s_x2
  jmp .sprite_col 
.s_x2:
  lda fuel_x 
  clc 
  adc #$08
  sec 
  sbc playerX 
  cmp #$11
  bcs .done 
.sprite_col:
  lda #%00100000
  sta $0212
.done:
  ; if any of the conditions for a collision are NOT met, we go here

  ; generate some random numbers and make assignments
RandomGen:
  jsr gen_random
.done:

  jsr put_y
  JMP GameEngineDone  ; we are done with the game engine code, so let's go to that label

;;;;;     Our Subroutines   ;;;;;

;;; Draw Routine ;;;

DrawRoutine:
  lda draw_flag
  bne DrawRoutineDone ; if the draw_flag is set, then don't do this - only once per frame!

  ; update our fuel position first
  dec fuel_x
  lda fuel_x
  clc 
  adc #$04
  cmp #LEFTWALL
  bcs NewColumnCheck ; continue if the fuel hasn't hit the wall yet
  ; if it has hit the wall, hide it behind the background
  lda #%00100000
  sta $0212

  ; our nametable swap check was here, but that causes flickering; now it is in NMI with the scroll variable

NewColumnCheck: ; we must first check to see if it's time to draw a new column
  lda scroll  ; we will only draw a new column of data every 8 frames, because each tile is 8px wide
  and #%00000111  ; see if divisible by 8
  bne DrawRoutineDone ; if it is not time, we are done
  ; else, execute this
  jsr DrawNewColumn

  lda columnNumber
  clc
  adc #$01
  and #%00111111 ; only 64 columns of data, throw away top bits to wrap
  sta columnNumber 
.done:

DrawRoutineDone:
  rts

;;; Draw a new column to the background ;;;

DrawNewColumn:
  ; calculate starting PPU address of the new column
  ; start with low byte
  lda scroll
  lsr a
  lsr a 
  lsr a ; shifting right 3 times divides by 8
  sta columnLow ; $00 to $1F, screen is 32 tiles wide
  ; time for the high byte; we will use the current nametable
  lda nametable
  eor #$01 ; invert lowest bit -- a = #$00 or #$01
  asl a ; a = #$00 or #$02
  asl a ; a = #$00 or #$04
  clc 
  adc #$20 ; add high byte of nametable base address ($2000)
  sta columnHigh ; this is now the high byte of the address to write to in the column

  lda columnNumber
  asl a 
  asl a 
  asl a 
  asl a 
  asl a
  sta sourceLow 
  lda columnNumber
  and #%11111000
  lsr a 
  lsr a 
  lsr a 
  sta sourceHigh

  LDA sourceLow       ; column data start + offset = address to load column data from
  CLC 
  ADC #LOW(columnData)
  STA sourceLow
  LDA sourceHigh
  ADC #HIGH(columnData)
  STA sourceHigh 

DrawColumn:  
  lda #$1E
  ldy #$00
  sta [buff_ptr], y ; $0400

  iny
  lda columnHigh
  sta [buff_ptr], Y ; $0401
  iny 
  lda columnLow
  sta [buff_ptr], y ; $0402

  iny
  lda #%00000100
  sta [buff_ptr], Y ; $0403
  ldx #$1E
  
  ; use buff_data_p to track in the loop
  lda buff_ptr 
  clc 
  adc #$04
  sta buff_data_p
  lda buff_ptr_2
  sta buff_data_p2

  ldy #$00
.loop:
  lda [sourceLow], y ; this originally started with y at 0, but now it's 4...
  sta [buff_data_p], y ; $0400 + y, which starts at 4
  iny
  dex
  bne .loop
.asteroid:
  lda num_objects
  beq .done

  ldy asteroid_y
  lda #$40 ; address of asteroid graphic
  sta [buff_data_p], y ; store the value in A at our buffer plus the y value we generated
.done:
  ; set the draw flag to ensure we only update graphics once per frame, then return
  inc draw_flag
  rts

;;; Update our sprite positions ;;;

UpdateSprites:
  LDA playerY
  STA $0200
  STA $0204
  CLC
  ADC #$08
  STA $0208
  STA $020C
.fuel:
  lda fuel_y
  sta $0210
  lda fuel_x
  sta $0213
.done:
  lda #$00
  sta sprite_draw_flag
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

;; Okay so this PRNG is pretty shitty, but whatever, it will work for now

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
  ; make sure the y value is between 4 and 34 ($04 and $22) - it has to fit in the buffer column
  sec 
  sbc #$04
  cmp #$23
  bcc .done ; carry will be clear if it is less than $23, so less than or equal to $22
.adjust:  ; if it is higher than $22, subtract $22 to attempt to bring it in range
  lda random_return
  sec 
  sbc #$22
  sta random_return
  jmp put_y ; check again
.done:
  sta asteroid_y
  rts 

;---------------------------------------------------
;; 4th 8kb bank -- Data tables

  .bank 3
  .org $E000
palette:
  .db $30,$00,$10,$0F,  $0F,$36,$17,$22,  $0F,$30,$21,$22,  $0F,$27,$17,$22   ;;background palette
  .db $22,$1C,$15,$14,  $22,$02,$38,$3C,  $0C,$17,$28,$39,  $0F,$1C,$2B,$39   ;;sprite palette

sprites:
      ;vert tile attr horiz
      ;player
  .db $80, $00, $02, $10   ;sprite 0
  .db $80, $01, $02, $18   ;sprite 1
  .db $88, $02, $02, $10
  .db $88, $03, $02, $18
      ; fuel
  .db $00, $04, $03, $00
      

columnData:
  .incbin "bkg.bin"

;---------------------------------------------------
;; Vectors

  .org $FFFA
  .dw NMI

  .dw RESET

  .dw 0

  .bank 4
  .org $0000
  .incbin "NewFile.chr"	; custom graphics file