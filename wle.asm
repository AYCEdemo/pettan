; Walle Length Encoding decoder

z_wle_src       = 0
z_wle_dst       = 2
wle_hold        = 4

decompress
; Decompress WLE data from z_wle_src to z_wle_dst
; then return the decompressed data length in xy
    lda #0
    sta wle_hold
    ; save this for later length calculation
    lda z_wle_dst+1
    pha
    lda z_wle_dst
    pha
    
_loop
    ldy #0
    lda (z_wle_src),y
    iny
    tax
    and #$c0
    beq _literal
    cmp #$40
    beq _repeat
    cmp #$80
    beq _increment
    
_copy
    cpx #$ff
    beq _done
    
    lda z_wle_src+1
    pha
    lda z_wle_src
    pha
    
    ; z_wle_src = z_wle_dst - *(z_wle_src) - 1
    lda z_wle_dst
    clc ; this is correct
    sbc (z_wle_src),y
    sta z_wle_src
    lda z_wle_dst+1
    sbc #0
    sta z_wle_src+1
    
    txa
    and #$3f
    tay
    iny
    jsr _memcpy_short
    jsr _add_dst_y
    
    pla
    sta z_wle_src
    pla
    sta z_wle_src+1
    ldy #2
    jsr _add_src_y
    jmp _loop
    
_literal
    jsr _get_length_and_load_extra_flag
    bne +
    ; short count
    txa
    pha
    ldx #0
    beq ++
    
+   ; long count
    lda (z_wle_src),y
    iny
    pha
+   jsr _add_src_y
    pla
    tay
    iny
    bne +
    inx
+   jsr _memcpy
    ; _memcpy doesn't add Y to to src and dst in the final stage
    jsr _add_src_y
    jsr _add_dst_y
    jmp _loop
    
_repeat
    jsr _repeat_increment_common
-   sta (z_wle_dst),y
    iny
    dex
    bne -
    jsr _add_dst_y
    jmp _loop
    
_increment
    jsr _repeat_increment_common
-   sta (z_wle_dst),y
    clc
    adc #1
    iny
    dex
    bne -
    sta wle_hold
    jsr _add_dst_y
    jmp _loop
    
_done
    ; length = (z_wle_dst) - (<TOS>)
    pla
    eor #$ff
    sec
    adc z_wle_dst
    tay
    pla
    eor #$ff
    adc z_wle_dst+1
    tax    
    rts
    
_get_length_and_load_extra_flag
    txa
    and #$20
    php
    txa
    and #$1f
    tax
    plp
    rts
    
_repeat_increment_common
    jsr _get_length_and_load_extra_flag
    beq +
    lda (z_wle_src),y
    iny
    sta wle_hold
+   jsr _add_src_y
    lda wle_hold
    inx
    ldy #0
    rts
    
_add_src_y
; z_wle_src += y
    tya
    clc
    adc z_wle_src
    sta z_wle_src
    bcc +
    inc z_wle_src+1
+   rts

_add_dst_y
; z_wle_dst += y
    tya
    clc
    adc z_wle_dst
    sta z_wle_dst
    bcc +
    inc z_wle_dst+1
+   rts

_memcpy
; Copy (z_wle_src) to (z_wle_dst) with length xy
    txa
    beq _memcpy_short
    
    tya
    pha
    ldy #0
-   .rept 2
        lda (z_wle_src),y
        sta (z_wle_dst),y
        iny
    .next
    bne -
    inc z_wle_src+1
    inc z_wle_dst+1
    dex
    bne -
    pla
    tay
    ; fall through
    
_memcpy_short
; Copy (z_wle_src) to (z_wle_dst) with length y
    tya
    tax
    ldy #0
-   lda (z_wle_src),y
    sta (z_wle_dst),y
    iny
    dex
    bne -
    rts
