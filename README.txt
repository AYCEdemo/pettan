If you want to build the demo:

python wlenc.py logo.bin logo.bin.wle 165
python xmconv.py music.xm music.bin
64tass -C -a -b -o main.o main.asm
python wlenc.py main.o main.o.wle
64tass -C -a -o demo.prg init.asm

If you want to build the standalone music player:

python xmconv.py music.xm music.bin
64tass -C -a -D STANDALONE=1 -o pettan.prg player.asm

(sorry for no make or shell script this time)
