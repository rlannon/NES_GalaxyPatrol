;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;          SOUND ENGINE          ;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

  .rsset $0300

sound_disable_flag  .rs 1
note_ptr            .rs 1
note_move_flag      .rs 1

;; Define constants for audio registers so we don't need to remember numbers

APUFLAGS = $4015
SQ1_ENV = $4000
SQ1_SWEEP = $4001
SQ1_LOW = $4002
SQ1_HIGH = $4003

SQ2_ENV = $4004
SQ2_SWEEP = $4005
SQ2_LOW = $4006
SQ2_HIGH = $4007

TRI_CTRL = $4008
TRI_LOW = $400A
TRI_HIGH = $400B

;; Subroutines

;; define our subroutines for our sound engine

sound_disable:  ; subroutine to disable the sound channels via $4015, or APUFLAGS
  lda #$00
  sta APUFLAGS
  lda #$01
  sta sound_disable_flag
  RTS

sound_load:   ; takes a number as input and indexes it to the proper sound or sfx
  ;; where we will load our sound
  RTS

sound_play_frame: ; subroutine to advance to the next "frame" (beat unit) in our music/sound
  lda sound_disable_flag
  bne .done   ; if the sound flag is set, don't advance
  ;; to be written later
.done:
  RTS

sound_engine_init:
  lda #$0F         ; enable square, triangle, and noise channels; disable dmc
  sta APUFLAGS     ; (initialize sound)

  lda #$30
  sta $4000
  sta $4004
  sta $400C
  lda #$80
  sta $4008

  lda #00
  sta sound_disable_flag  ; we just initialized the APU, so the sound_disable_flag should be OFF
  sta note_move_flag

  lda #$08
  sta SQ1_SWEEP
  sta SQ2_SWEEP       ; disable sweep units to avoid unwanted silencing of low notes

  lda #C3
  sta note_ptr        ; starting note = C3
  rts

  .include "note_table.i"