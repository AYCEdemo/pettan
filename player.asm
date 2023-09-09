samp_addr = $00
engine_rate_hz = 50 ; TODO make this a part of module data
engine_rate = (1000000 / engine_rate_hz) - 2

cinv1 = $0219 ; basic 1
cinv2 = $90   ; basic 2+
iorb1 = $e812
crb1 = $e813
iorbv = $e840
tim1 = $e844
tim2 = $e848
sreg = $e84a
acr = $e84b
ier = $e84e

    .weak
STANDALONE  = 0
    .endweak

    .if STANDALONE != 0
* = $0401
    .word (+), 2020 ; pointer, line number
    .null $9e, format("%d", player_start); SYS #start
+   .word 0 ; basic line end
    .fi

_zpvars     = samp_addr+size(samp)
player_ztmp = _zpvars
patptrlo    = _zpvars+2
patptrhi    = _zpvars+4

    ; don't forget to point player_update_callback to a valid routine before calling this!
player_start
    ; read music data
    sei
    lda #>musdat.data
    sta player_ztmp
    sta ordptr+1
    ; lda #>musdat
    clc
    adc musdat.wavp
    sta wave_ptr
    lda #<musdat.data
    sta ordptr
    ldy #2
-   clc
    adc musdat.ords
    bcc +
    inc player_ztmp
+   sta ordptr,y
    iny
    pha
    lda player_ztmp
    sta ordptr,y
    iny
    pla
    cpy #8
    bne -
    ldx player_ztmp
    clc
    adc musdat.ords
    bcc +
    inx
+   sta patptrlo
    stx patptrlo+1
    clc
    adc musdat.pats
    bcc +
    inx
+   sta patptrhi
    stx patptrhi+1

    lda #0
    tax
-   sta player_vars,x
    inx
    cpx #(player_vars_end-player_vars)
    bne -
    lda musdat.spd
    sta curspd
    sta curspd+2
    sta curspd+4
    sta curspd+6

    ldx #0
-   lda samp_,x
    sta samp,x
    inx
    cpx #size(samp)
    bne -
    ; setup I/O chips
    lda #$3c ; disable vblank interrupt
    sta crb1
    lda iorb1 ; clear int flag
    lda #1
    sta tim2
    ldy #0
    sty tim2+1
    lda #%01010000
    sta acr
    lda #%01111111
    sta ier
    lda #%11000000
    sta ier
    lda #<vbi
    sta cinv1
    sta cinv2
    lda #>vbi
    sta cinv1+1
    sta cinv2+1
    
    lda #<engine_rate
    ldx #>engine_rate
    sta tim1
-   lda iorbv
    and #$20 ; vblank flag
    bne -
    stx tim1+1

    jmp samp

samp_
    .logical samp_addr
samp   .block
    lda #0 ; 2
pos0l = *-1
    ; clc
    adc #0 ; 2
freq0l = *-1
    sta pos0l ; 3
    lda pos0 ; 3
    adc #0 ; 2
freq0h = *-1
    sta pos0 ; 3
    lda #0
pos1l = *-1
    ; clc
    adc #0
freq1l = *-1
    sta pos1l
    lda pos1
    adc #0
freq1h = *-1
    sta pos1
    lda #0
pos2l = *-1
    ; clc
    adc #0
freq2l = *-1
    sta pos2l
    lda pos2
    adc #0
freq2h = *-1
    sta pos2
    lda #0
pos3l = *-1
    ; clc
    adc #0
freq3l = *-1
    sta pos3l
    lda pos3
    adc #0
freq3h = *-1
    sta pos3
             ; = 60
    
    lda bilence ; 4
pos0 = *-2
    and #%00010001 ; 2
    sta out1 ; 3
    lda bilence ; 4
pos1 = *-2
    and #%00100010 ; 2
    sta out2 ; 3
    lda bilence ; 4
pos2 = *-2
    and #%01000100 ; 2
    sta out3 ; 3
    lda bilence ; 4
pos3 = *-2
    and #%10001000 ; 2
    ora #0 ; 2
out1 = *-1
    ora #0 ; 2
out2 = *-1
    ora #0 ; 2
out3 = *-1
    sta sreg ; 4
    cli ; 2
    ; interrupt will only occur here
    sei ; 2
    jmp samp ; 3
             ; = 50
             ; = 110

    .bend
    .here

vbi
    lda tim1 ; clear int flag
    
    ; read current position to avoid phase reset in register update
    lda samp.pos0
    sta poss
    lda samp.pos1
    sta poss+2
    lda samp.pos2
    sta poss+4
    lda samp.pos3
    sta poss+6
    
    ldx #0
    
update_ch
    lda curctr,x
    beq +
    jmp _done_ch_row
+   ldy curord,x
    cpy musdat.ords
    bcc +
    jmp _done_ch_row
+   lda currow,x
    bne _done_pat
    ; load a new pattern pointer to player_ztmp
    lda ordptr,x
    sta player_ztmp
    lda ordptr+1,x
    sta player_ztmp+1
-   lda (player_ztmp),y ; pattern number
    cmp #$ff ; end
    bne +
    sta curord,x
    jmp _done_ch_row
+   cmp #$fe ; jump
    bne +
    iny
    lda (player_ztmp),y ; destination
    sta curord,x
    tay
    clc
    bcc -
+   tay
    lda (patptrlo),y
    sta curptr,x
    lda (patptrhi),y
    clc
    adc #>musdat
    sta curptr+1,x
    lda currow,x
_done_pat
    tay
    lda curptr,x
    sta player_ztmp
    lda curptr+1,x
    sta player_ztmp+1
    lda (player_ztmp),y
    beq _done_note ; blank
    ; cmp #$80
    ; bcs _proc_fx
    cmp #$79 ; note off
    bcc +
    inc reg_changed
    lda #0
    sta note_on,x
    beq _done_note
+   sta note_on,x
    tay
    ; TODO check toneporta
    lda pitchtablo,y
    sta freqs,x
    ; sta freqs_new,x
    lda pitchtabhi,y
    sta freqs+1,x
    ; sta freqs_new+1,x
    ; lda #0
    ; sta poss,x
    inc reg_changed
    ldy currow,x
_done_note
    iny
_proc_fx
    lda (player_ztmp),y
    cmp #$80
    bcc _done_fx
    cmp #$ff ; end
    beq _pattern_end
    cmp #$f0
    bcs _fx_long
    cmp #$e0
    bcs _fx_chspd
    bcc _fx_wavesel
_fx_long
    beq _fx_wavesel_long
    cmp #$f1
    beq _fx_portaup
    cmp #$f2
    beq _fx_portadown
    bne _fx_chspd_long
    ; TODO more effects
_fx_wavesel_long
    iny
    lda (player_ztmp),y
    bne _fx_wavesel_common
_fx_wavesel
    and #$0f
_fx_wavesel_common
    clc
    adc wave_ptr
    sta wave_page,x
    jmp _fx_end
_fx_chspd_long
    iny
    lda (player_ztmp),y
    bne _fx_chspd_common
_fx_chspd
    and #$0f
_fx_chspd_common
    clc
    adc #1
    sta curspd,x
    jmp _fx_end
_fx_portaup
    iny
    lda (player_ztmp),y
    sta freqs_dta,x
    clc
    lda #0
    beq _fx_porta_common
_fx_portadown
    iny
    lda #0
    sec
    sbc (player_ztmp),y
    sta freqs_dta,x
    lda #0
    sbc #0
_fx_porta_common
    sta freqs_dta+1,x
    ; jmp _fx_end
_fx_end
    iny
    bne _proc_fx
_pattern_end
    inc curord,x
    ldy #0
_done_fx
    tya
    sta currow,x
    lda curspd,x
    sta curctr,x
_done_ch_row
    dec curctr,x

update_ch_state
    ; TODO effects
    lda note_on,x
    bne _on
    ; do note off
    sta freqs,x
    sta freqs+1,x
    sta poss,x
    lda #>bilence
    sta poss+1,x
    bne done_ch
_on
    lda freqs_dta,x
    ora freqs_dta+1,x
    beq +
    inc reg_changed
    ; lda freqs_new,x
+   lda freqs,x
    clc
    adc freqs_dta,x
    sta freqs,x
    ; lda freqs_new+1,x
    lda freqs+1,x
    adc freqs_dta+1,x
    sta freqs+1,x
    lda wave_page,x
    sta poss+1,x

done_ch
    inx
    inx
    cpx #8
    beq +
    jmp update_ch
+
    lda reg_changed
    beq vbi_exit
    
update_reg
_freqs  = [samp.freq0l, samp.freq0h, samp.freq1l, samp.freq1h,
           samp.freq2l, samp.freq2h, samp.freq3l, samp.freq3h]
_poss   = [samp.pos0, samp.pos0+1, samp.pos1, samp.pos1+1,
           samp.pos2, samp.pos2+1, samp.pos3, samp.pos3+1]
_x := 0
    .rept 8
    lda freqs+_x
    sta _freqs[_x]
    lda poss+_x
    sta _poss[_x]
_x := _x + 1
    .next
    lda #0
    sta reg_changed

vbi_exit
    .if STANDALONE == 0
        jsr _callback
    .fi
    pla
    tay
    pla
    tax
    pla
    rti

_callback
    jmp (player_update_callback)

    .align 8
ordptr      .fill 8

player_vars

freqs       .fill 8
poss        .fill 8
freqs_new   .fill 8
freqs_dta   .fill 8
curptr      .fill 8
curord      .fill 8
currow = curord + 1
curspd      .fill 8
curctr = curspd + 1
note_on     .fill 8
wave_page = note_on + 1
reg_changed .byte ?

player_vars_end

wave_ptr    .byte ?
player_update_callback  .word ?

    .align $100
pitchtab = (2.**((range(120)-81)/12.))*440*65536*110/1000000
bilence
    .fill 254-len(pitchtab)*2, 0
pitchtablo  .byte 0, <pitchtab
pitchtabhi  .byte 0, >pitchtab
    
    .align $100
musdat  .block
    ; .byte 0, 0, ords, pats, waves, waveptr, spd
ords = musdat + 2
pats = musdat + 3
wavs = musdat + 4
wavp = musdat + 5
spd  = musdat + 6
data = musdat + 16

    .binary "music.bin"
    
    .bend
