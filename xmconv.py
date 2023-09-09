"""
Supported commands: 1xx, 2xx, Fxx

Portamento commands are converted directly but played like FamiTracker in the engine,
see thingscant_pet.xm for more details
Fxx tempo values are treated as speed
"""

import argparse
import math
import struct
import array
import random

parser = argparse.ArgumentParser(description='Converts .xm module to PETtan music data')
parser.add_argument('fi', metavar='I', type=argparse.FileType('rb'), help='Input file name')
parser.add_argument('fo', metavar='O', type=argparse.FileType('wb'), help='Output file name')
nsp = parser.parse_args()

def s8(a): return int.from_bytes(a.read(1), "little", signed=True)
def u8(a): return int.from_bytes(a.read(1), "little", signed=False)
def le16(a): return int.from_bytes(a.read(2), "little", signed=False)
def le32(a): return int.from_bytes(a.read(4), "little", signed=False)

class XMRow:
    def __init__(self, a):
        self.note = 0
        self.ins = 0
        self.vol = 0
        self.cmd = 0
        self.par = 0

        info = u8(a)
        if not info & 0x80: # full row
            self.note = info & 0x7f
            info = 0xfe
        if info & 0x01:
            self.note = u8(a)
        if info & 0x02:
            self.ins = u8(a)
        if info & 0x04:
            self.vol = u8(a)
        if info & 0x08:
            self.cmd = u8(a)
        if info & 0x10:
            self.par = u8(a)

class XMSampleHeader:
    def __init__(self, a):
        self.size = le32(a)
        self.loopstart = le32(a)
        self.looplen = le32(a)
        self.volume = u8(a)
        self.finetune = s8(a)
        self.type = u8(a)
        self.pan = u8(a)
        self.c5note = s8(a)
        self.reserved = u8(a)
        self.name = fin.read(22).decode().strip()

fin = nsp.fi
fou = nsp.fo
if fin.read(17) != b"Extended Module: ":
    raise Exception("Invalid magic number. This is not .xm module file!")

name = fin.read(20).decode().strip()
if name == "":
    name = fin.name
print("Converting {} into PETtan data...".format(name))

fin.seek(1, 1) # EOF char
tracker = fin.read(20).decode().strip()
version = le16(fin)
if version < 0x104:
    raise Exception("Unsupported file version!")
hsize = le32(fin)

onum = le16(fin)
orst = le16(fin)
chs = le16(fin)
pnum = le16(fin)
inum = le16(fin)
flags = le16(fin)
spe = le16(fin)
tem = le16(fin)

ordl = array.array("B")
ordl.fromfile(fin, onum)
if onum == 0: # handle OpenMPT empty order list
    onum = 1
    ordl.append(0)
fin.seek(hsize + 60)

print("Tracker: " + tracker)
print("{} instruments, {} patterns and {} patterns long.".format(inum, pnum, onum))
print("[Initial] Speed {} | Tempo {}".format(spe, tem))
print("Pattern order: " + " ".join([str(i) for i in ordl]))

if tem != 125:
    print("Warning: Tempo is not 125 bpm!")
if chs > 4:
    print("Warning: Only first 4 channels will be used!")

# Patterns

patpl = []
for i in range(pnum):
    fpos = fin.tell()
    hsize = le32(fin)
    fin.seek(1, 1) # packing type
    rows = le16(fin)
    psize = le16(fin)
    if rows == 0:
        rows = 64
    if psize == 0: # empty pattern
        rows = 0
    fin.seek(fpos + hsize)

    patpl.append([[XMRow(fin) for k in range(chs)] for j in range(rows)])
    fin.seek(fpos + hsize + psize)

# Instruments

waves = []
transposes = []
for i in range(inum):
    fpos = fin.tell()
    hsize = le32(fin)
    fin.seek(23, 1) # instrument name, garbage byte
    snum = le16(fin)
    fin.seek(fpos + hsize)

    sheaders = [XMSampleHeader(fin) for j in range(snum)]
    fpos = fin.tell()
    # process the first sample's data for wave
    procdsamp = []
    transpose = 0
    if snum == 0:
        print("Warning: Instrument {} contains no samples!".format(i+1))
    else:
        sheader = sheaders[0]
        transpose = sheader.c5note+sheader.finetune/128

        dtype = "B"
        ssize = sheader.size
        is16 = sheader.type & 0x10 # 16-bit sample
        if is16:
            dtype = "H"
            ssize &= ~1
        sampdata = array.array(dtype)
        sampdata.fromfile(fin, ssize)
        slen = len(sampdata)

        # decode dpcm back to pcm
        bound = 65536 if is16 else 256
        val = 32768 if is16 else 128
        loopdiv = 2 if is16 else 1
        for j in range(slen):
            newval = (val + sampdata[j]) % bound
            sampdata[j] = newval
            val = newval
        loopstart = sheader.loopstart // loopdiv
        looplen = sheader.looplen // loopdiv
        tploop = 0
        if looplen == 0:
            print("Warning: Instrument {}'s sample is a one-shot sample. ".format(i+1) +
                "The first 256 samples will be read instead.")
            sampdata = sampdata[:256]
        else:
            # compensate a 256 samples stretch
            if looplen > 0:
                transpose += math.log2(256/looplen)*12
            sampdata = sampdata[loopstart:loopstart+looplen]
        procdsamp = [i / (bound - 1) for i in sampdata]

    waves.append(procdsamp)
    transposes.append(math.floor(transpose+.5))
    fin.seek(fpos)

    for j in range(snum):
        fin.seek(sheaders[j].size, 1)

fin.close()

"""
Pattern format:

note <fx ...>

$00     = empty
$01-$78 = note on (C0-B9)
$7f     = note off

$80-$8f = wave set
$f0 xx  = wave set
$ff     = pattern end
"""

print("\nConverting pattern data...")

XM_NOTE_OFF = 97
GBM_NOTE_OFF = 127
GBM_NOTE_EMPTY = 0

# pass 1: instrument usage tally

patuse = set(ordl)
waveuse = [set() for i in range(4)]
waveuseall = set()

for i in patuse:
    pat = patpl[i]
    for j in pat:
        for k in range(min(len(j), 4)):
            ins = j[k].ins
            if ins > 0:
                waveuse[k].add(ins)
                waveuseall.add(ins)
print(waveuse)

snum = max([len(i) for i in waveuse])
empties = [snum - len(i) for i in waveuse]
insmap = [{} for i in range(4)]
# make the most used comes first so that the wave data is compressed better
COMBI = [[0,1,2,3],[0,1,2],[0,1,3],[0,2,3],[1,2,3],[0,1],[0,2],[0,3],[1,2],[1,3],[2,3],[0],[1],[2],[3]]
count = [0,0,0,0]

for i in COMBI:
    shared = set(waveuse[i[0]])
    for j in i[1:]:
        shared &= waveuse[j]
    for j in shared:
        for k in range(4):
            if k in i:
                waveuse[k].remove(j)
                insmap[k][j] = count[k]
                count[k] += 1
            else:
                if empties[k] > 0:
                    count[k] += 1
                    empties[k] -= 1

print(insmap)

# pass 2: instrument correction and format conversion

patplou = {}
print(transposes)

for i in patuse:
    pat = patpl[i]
    patou = [bytearray() for j in range(4)]
    curins = [0, 0, 0, 0]
    curspd = spe
    for j in pat:
        speed_change = 0
        porta_hold = [-1, -1, -1, -1]
        for k in range(min(len(j), 4)):
            note = j[k].note
            ins = j[k].ins
            cmd = j[k].cmd
            par = j[k].par

            if note == 0 or note > XM_NOTE_OFF:
                note = GBM_NOTE_EMPTY
            elif note == XM_NOTE_OFF:
                note = GBM_NOTE_OFF
            else:
                note = min(max(note + transposes[ins-1] - 12, 1), 120)

            patou[k].append(note)
            if ins > 0 and curins[k] != ins:
                curins[k] = ins
                ins = insmap[k][ins]
                if ins > 15:
                    patou[k] += bytearray([0xf0, ins])
                else:
                    patou[k].append(ins + 0x80)

            if 1 <= cmd < 3 and porta_hold[k] != par:
                porta_hold[k] = par
                patou[k] += bytearray([0xf0+cmd, par])
            elif cmd == 15 and curspd != par:
                curspd = par
                speed_change = par
            
            # TODO more effect commands

        if 1 <= speed_change < 17:
            for k in range(4):
                patou[k].append(0xdf+speed_change)
        elif speed_change >= 17:
            for k in range(4):
                patou[k] += bytearray([0xfd, speed_change-1])

    for k in range(4):
        patou[k].append(0xff)
        if len(patou[k]) > 256:
            raise Exception("Pattern {} Channel {} is over 256 bytes when converted!".format(i, k+1))
        patplou[i+k*pnum] = patou[k]

# pass 3: final pattern deduplication

ordlou = []
for i in range(4):
    for j in ordl:
        ordlou.append(j+i*pnum)
ordq = set(ordlou)
while len(ordq) > 0:
    base = ordq.pop()
    for i in set(ordq):
        if patplou[base] == patplou[i]:
            for j in range(len(ordlou)):
                if ordlou[j] == i:
                    ordlou[j] = base
            ordq.discard(i)
# print(ordlou)
ordmap = {}
ordmaprev = []
count = 0
for i in range(onum):
    for j in range(4):
        cord = ordlou[i+j*onum]
        if cord not in ordmap:
            ordmap[cord] = count
            ordmaprev.append(cord)
            count += 1
print(ordmap)

"""
File format:

ds 2    (reserved)
byte    pattern table size
byte    patterns count
byte    waves count
byte    wave data page offset
byte    module speed
ds 9    (reserved)
rept 4
    rept pattern table size
        byte    pattern index
rept patterns count
    byte    pattern data offset (low byte)
rept patterns count
    byte    pattern data offset (high byte)
ds ?    pattern data
ds ?    page align padding
rept waves count
    ds 256  wave data (%43214321)
"""

print("\nConverting samples...")

fou.write(b"\x00"*16) # header will be written later

SAMP_VALS = ((0,1,17),(0,16,17),(0,1,17),(0,16,17))
wavesou = [bytearray([0]*256) for i in range(snum)]
for i in waveuseall:
    samp = waves[i-1]
    if len(samp) <= 0:
        continue
    step = len(samp) / 256
    procdsamp = [samp[int(step*j)] for j in range(256)]
    minval = min(procdsamp)
    # # TPDF dither (too noisy)
    # random.seed(-3662269746218189933)
    # for j in range(256):
    #     val = procdsamp[j] - minval
    #     quan = int(val*2)
    #     error = val*2 - quan
    #     if error > random.triangular(): quan += 1
    #     procdsamp[j] = min(quan, 2)
    for j in range(256):
        val = procdsamp[j] - minval
        quan = int(val*3)
        procdsamp[j] = min(quan, 2)
    # print(i, procdsamp)
    
    for j in range(4):
        if i in insmap[j]:
            insou = insmap[j][i]
            for k in range(256):
                wavesou[insou][k] |= SAMP_VALS[j][procdsamp[k]] << j
# print(wavesou)

for i in range(4):
    for j in range(onum):
        fou.write(ordmap[ordlou[j+i*onum]].to_bytes(1, "little", signed=False))
    fou.write(bytearray([0xfe, orst])) # TODO no looping option
onum += 2
pnum = len(ordmap)
patptrpos = fou.tell()
patptrs = bytearray(pnum*2)
fou.seek(pnum*2, 1)
for i in range(pnum):
    pos = fou.tell()
    patptrs[i] = pos % 256
    patptrs[i+pnum] = pos // 256
    fou.write(patplou[ordmaprev[i]])

spage = math.ceil(fou.tell() / 256)
fou.seek(patptrpos)
fou.write(patptrs)
fou.seek(spage*256)
for i in wavesou:
    fou.write(i)

fou.seek(2)
fou.write(struct.pack("<BBBBB", onum, pnum, snum, spage, spe))

fou.close()
print("Completed!")
