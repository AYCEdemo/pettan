# 000x xxxx   - literal short
# 001x xxxx X - literal long
# 010x xxxx   - fill hold
# 011x xxxx Y - fill Y, hold=Y
# 100x xxxx   - inc hold
# 101x xxxx Y - inc Y, hold=Y
# 11xx xxxx Y - copy from -Y for X
# 1111 1111   - end

import sys


def writelit(buf, start, end):
    # print("lit {}".format(buf[start:end]))
    out = bytearray()
    while start < end:
        l = min(end - start, 8192) - 1
        if l > 31:
            out += bytearray([0x20 + (l >> 8), l & 255]) + buf[start : start + l + 1]
        else:
            out += bytearray([l]) + buf[start : start + l + 1]
        start += 8192
    return out


def encodeWLE(buf):
    out = bytearray()
    hold = 0
    lit = 0
    pos = 0
    while pos < len(buf):
        pos2 = pos
        while pos2 < min(len(buf), pos + 32) and buf[pos2] == buf[pos]:
            pos2 += 1
        longest_fill = pos2 - pos
        pos2 = pos
        curinc = buf[pos]
        while pos2 < min(len(buf), pos + 32) and buf[pos2] == curinc:
            curinc += 1
            pos2 += 1
        longest_inc = pos2 - pos
        if buf[pos] == hold:
            longest_fill += 1
            longest_inc += 1
        copies = []
        for j in range(max(pos - 256, 0), pos):
            if buf[j] == buf[pos]:
                copies.append((j, 1))
        longest_copy = (-1, -1)
        while len(copies) > 0:
            longest_copy = copies.pop(0)
            cmdlen = longest_copy[1]
            if (
                pos + cmdlen < len(buf)
                and buf[longest_copy[0] + cmdlen] == buf[pos + cmdlen]
            ):
                copies.append((longest_copy[0], cmdlen + 1))
        if longest_copy[1] > 63:
            longest_copy = (longest_copy[0], 63)
        cmd = max((longest_copy[1], 1), (longest_inc, 2), (longest_fill, 3))
        if cmd[0] > 2:
            if lit > 0:
                out += writelit(buf, pos - lit, pos)
            lit = 0
            cmdlen = cmd[0]
            if cmd[1] == 1:
                out += bytearray([0xC0 + cmdlen - 1, pos - longest_copy[0] - 1])
                # print("copy {} to {}".format(longest_copy[0] - pos, longest_copy[0] - pos + cmdlen))
            elif cmd[1] == 2:
                if buf[pos] == hold:
                    cmdlen -= 1
                    out += bytearray([0x80 + cmdlen - 1])
                else:
                    out += bytearray([0xA0 + cmdlen - 1, buf[pos]])
                # print("inc {} for {}".format(buf[pos], cmdlen))
                hold = buf[pos] + cmdlen
            else:
                if buf[pos] == hold:
                    cmdlen -= 1
                    out += bytearray([0x40 + cmdlen - 1])
                else:
                    out += bytearray([0x60 + cmdlen - 1, buf[pos]])
                # print("fill {} for {}".format(buf[pos], cmdlen))
                hold = buf[pos]
            pos += cmdlen
        else:  # literal
            lit += 1
            pos += 1
    if lit > 0:
        out += writelit(buf, pos - lit, pos)
    out += b"\xff"  # end
    return out


if __name__ == "__main__":
    fi = open(sys.argv[1], "rb")
    fo = open(sys.argv[2], "wb")
    # modified for this demo: if arg 3 exists, xor the data with arg 3's number
    dat = fi.read()
    if len(sys.argv) > 3:
        xorval = int(sys.argv[3])
        dat = bytearray([i^xorval for i in dat])
    fo.write(encodeWLE(dat))

