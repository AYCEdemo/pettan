* = $400 ; must match main_start in init.asm

LOGO_XOR = $a5

ztmp = $80
scrollbase_40 = $8000+24*40
scrollbase_80 = $8000+24*80

main_start
    ; a = 80-column machine flag, 0 = 40, 1 = 80
    sta is40
    ; the code is for 40-column, patch parts code if it's 80-column
    cmp #0
    beq _skip
    lda #4
    sta part1.chars
    lda #$87
    sta part1.range
    lda #<scrollbase_80
    sta scrollbase
    sta part5.scrollbase
    lda #>scrollbase_80
    sta scrollbase+1
    sta part5.scrollbase+1
    lda #<(scrolltext-79)
    sta scroll_rst
    lda #>(scrolltext-79)
    sta scroll_rst+1
    lda #<(scrolltext+size(scrolltext)-80)
    sta scroll_end
    lda #>(scrolltext+size(scrolltext)-80)
    sta scroll_end+1

_skip
    lda #0
    sta ztmp
    lda #$80
    sta ztmp+1
    lda #<part1
    sta player_update_callback
    lda #>part1
    sta player_update_callback+1
    jmp player_start

part1   .block
    ; "reveal" the logo
    ldx #0
cnt = *-1
    cpx #32 ; halt after 32 frames
    bcs skip
    ldx #2
chars = *-1
    ldy #0
-   lda (ztmp),y
    eor #LOGO_XOR
    sta (ztmp),y
    lda ztmp
    clc
    adc #11
    sta ztmp
    lda ztmp+1
    adc #0
    and #$83
range = *-1
    sta ztmp+1
    dex
    bne -
    ldx cnt

skip
    inx
    cpx #16*3
    bne +
    ldx #0
    dec pats
    bne +
    lda #<part2
    sta player_update_callback
    lda #>part2
    sta player_update_callback+1
+   stx cnt
    rts

pats    .byte 16
ticks   .byte 16*3
    .bend

part2   .block
    ; delay
    dec cnt
    bne +
    lda #<delay_scroll
    sta player_update_callback
    lda #>delay_scroll
    sta player_update_callback+1
    jmp reset_scroller
+   rts

cnt     .byte 0 ; 256
    .bend

delay_scroll
    dec _cnt
    beq +
    rts
+   lda #4
    sta _cnt
    jmp part3
delay_scroll_callback = *-2

_cnt    .byte 1

reset_scroller
    ldx #40
    lda is40
    beq +
    ldx #80
+   stx scrolllen
    stx part3.cnt
    lda scroll_rst
    sta ztmp
    lda scroll_rst+1
    sta ztmp+1
    lda #<part3
    sta delay_scroll_callback
    lda #>part3
    sta delay_scroll_callback+1
    rts

scroller_common
-   lda (ztmp),y
    sta scrollbase_40,y
scrollbase = *-2
    iny
    cpy #40
scrolllen = *-1
    bne -
    inc ztmp
    bne +
    inc ztmp+1
+   rts

part3   .block
    ; scroller run in
    dec cnt
    ldy cnt
    jsr scroller_common
    lda cnt
    bne +
    lda #<part4
    sta delay_scroll_callback
    lda #>part4
    sta delay_scroll_callback+1
+   rts

cnt         .byte ?
    .bend

part4   .block
    ; scroller intermediate
    ldy #0
    jsr scroller_common
    lda ztmp+1
    cmp scroll_end+1
    bcc +
    lda ztmp
    cmp scroll_end
    bcc +
    lda #<part5
    sta delay_scroll_callback
    lda #>part5
    sta delay_scroll_callback+1
+   rts
    .bend

part5   .block
    ; scroller run out
    ldy #0
    lda scrolllen
    beq +
    jsr scroller_common
+   lda #32 ; blank char
    sta scrollbase_40,y
scrollbase = *-2
    lda scrolllen
    beq +
    dec scrolllen
    rts
+   jmp reset_scroller
    .bend

scrolltext  .block
    .enc "screen"
    .text "i swear, who in their right mind would put a sid chip inside a "
    .text "pet while it can make nice tunes on its own!? hey guys, zlew on "
    .text "the keys here! i know i've been teasing a game boy color prod "
    .text "from us for the longest time, but that's still in the works. "
    .text "in the meantime, pigu has decided to grace us with a treat for "
    .text "a little machine that you guys call ""pet"" and we like to call "
    .text """babe magnet""! it's called ""pettan"" and it is a 4-channel "
    .text "beeper engine! you write your tunes in a pc tracker of your "
    .text "choice using any 3-level samples (yes, you can still do sidsound), "
    .text "then yeet it into a converter to produce a prg ready to be loaded "
    .text "on hardware or in emu! and that's exactly what you miss out on if "
    .text "you don't hire the right person, mr. murray... the best thing is, you "
    .text "still have cpu time to do other things! of course it'll sound "
    .text "crushed, but hey, if tim follin could write delicious flat tunes "
    .text "in the '80s, so can you in 2020. the tune you're hearing right "
    .text "now is what happens when i attempt to write a funky tune on a tight "
    .text "schedule (if you wanna do that, please consult your nearest sid "
    .text "musician). anyway, pettan (and this tune) are available for you "
    .text "all to toy with right now at http://ayce.seawavescollective.net! "
    .text "that's all for now, see you guys hopefully in person soon! "
    .text "greets to: =tea lovers commity= =cncd= =marquee design= "
    .text "=triad= =fairlight= =titan= =botb= =tristesse= =speccy.pl= "
    .text "the text do the loop now . . ."
    .enc "none"
    .bend

scroll_rst  .word scrolltext-39
scroll_end  .word scrolltext+size(scrolltext)-40
is40        .byte ?

    .include "player.asm"
