* = $0401
    .word (+), 0             ; set graphics mode on basic 4 machines because
    .null $99, $22, $8e, $22 ; they also manipulate CRTC for some reason
+   .word (+), 2020
    .null $9e, format("%d", init); SYS #init
+   .word 0 ; basic end

load_size   = size(program)
load_addr   = $4000 - load_size
main_start  = $0400
logobuf     = main_start
is40        = $80
iorbv       = $e840

init
    .if (<load_size) != 0
        ldy #<load_size
-       dey
        lda program+(>load_size)*256,y
        sta load_addr+(>load_size)*256,y
        cpy #0
        bne -
    .fi
    .if (>load_size) != 0
        ldx #>load_size
        .if <load_size == 0
            ldy #0
        .fi
-       dey
        lda program+((>load_size)-1)*256,y
_src = *-2
        sta load_addr+((>load_size)-1)*256,y
_dst = *-2
        cpy #0
        bne -
        dec _src+1
        dec _dst+1
        dex
        bne -
    .fi
    jmp program.start

program .block
    .logical load_addr

start
    sei
-   lda iorbv
    and #$20 ; vblank flag
    bne -

load_logo
    ; decompress logo graphics, since the data is for 80-column machines
    ; it can be decompressed directly into the character RAM
    ; for 40-column machines, it will be decompressed into a buffer
    ; then only odd characters will be copied and packed

    ; detect 80-column machines
    clc
    ldx #>logobuf
    lda #0
    sta $8000
    sta $8400
    lda #$55
    sta $8400
    lda $8000 ; mirrored?
    bne _col40
    lda #$55
    cmp $8400 ; open bus?
    bne _col40
    ; c = 80, nc = 40
    sec
    ldx #$80
_col40
    php ; save carry flag for later

    lda #<logo_compressed
    sta 0
    lda #>logo_compressed
    sta 1
    lda #0
    sta 2
    stx 3
    jsr decompress

    plp
    php
    bcs load_demo ; skip copying

    ldx #>1024
    ldy #0
-   lda logobuf,y
_src1 = *-2
    sta $8000,y
_dst1 = *-2
    inc _src1 ; skip odd characters
    iny
    bne -
    inc _src1+1
    inc _src1+1
    inc _dst1+1
    dex
    bne -

load_demo
    lda #<main_compressed
    sta 0
    lda #>main_compressed
    sta 1
    lda #<main_start
    sta 2
    lda #>main_start
    sta 3
    jmp load_demo_2

logo_compressed .binary "logo.bin.wle"
main_compressed .binary "main.o.wle"

load_demo_2
    jsr decompress

    plp
    lda #0
    adc #0
    jmp main_start

    .include "wle.asm"

    .here
    .bend
