import sys

if len(sys.argv) < 3:
	exit()

mode = sys.argv[1]

def hex_unpack(filename):
	# we're dealing with tiny amounts of data and assuming valid input, storing memory as a dictionary is gross but fine
	memory = {}
	cur_segment_base = 0

	for l in open(filename):
		l = l.strip()

		if l[0] != ":":
			raise Exception("malformed hex file")
		
		bytecount = int(l[1:3], 16)
		address = int(l[3:7], 16)
		type = int(l[7:9], 16)
		data = [int(l[9 + v : 9 + v + 2], 16) for v in range(0, bytecount * 2, 2)]
		checksum = int(l[-2:], 16)
		
		if type != 0:
			print(hex(bytecount), hex(address), hex(type), data, hex(checksum))
		
		if type == 0x00:
			# Data
			memory[cur_segment_base + address] = data
		elif type == 0x01:
			# End Of File
			break
		# elif type == 0x02:
		# 	# Extended Segment Address
		# elif type == 0x03:
		# 	# Start Segment Address
		elif type == 0x04:
			# Extended Linear Address
			cur_segment_base = (data[0] << 24) | (data[1] << 16)
			print(hex(cur_segment_base))
		# elif type == 0x05:
		# 	# Start Linear Address

	cur_segment = []
	cur_segment_address = sorted(memory.keys())[0]
	segments = [(cur_segment_address, cur_segment)]

	for address in sorted(memory.keys()):
		data = memory[address]
		if cur_segment_address + len(cur_segment) == address:
			cur_segment += data
		else:
			segments += [(cur_segment_address, cur_segment)]
			cur_segment = data
			cur_segment_address = address

	if cur_segment_address != segments[0][0]:
		segments += [(cur_segment_address, cur_segment)]

	for (cur_segment_address, cur_segment) in segments:
		open(filename + "_unpacked_" + ("%08X" % cur_segment_address) + ".bin", "wb").write(bytearray(cur_segment))

def hex_pack(args):
	prev_address = 0xffffffffff
	for i in range(0, len(args), 2):
		base = int(args[i], 16)
		file = args[i + 1]
		data = bytearray(open(file, "rb").read())
		for cursor in range(0, len(data), 0x10):
			line_data = data[cursor : cursor + 0x10]
			address = base + cursor
			if (address >> 16) != (prev_address >> 16):
				line = ":02000004%04X" % (address >> 16)
				checksum = 2 + 4 + (address >> 16) + (address >> 24)
				checksum = (((~checksum) & 0xff) + 1) & 0xff
				line += "%02X" % checksum
				print(line)
			line = ":%02X%04X00" % (len(line_data), (address & 0xffff))
			checksum = len(line_data) + (address >> 8) + address
			for b in line_data:
				line += "%02X" % b
				checksum += b
			checksum = (((~checksum) & 0xff) + 1) & 0xff
			line += "%02X" % checksum
			print(line)
			prev_address = address
	print(":00000001FF")

if mode == "unpack":
	hex_unpack(sys.argv[2])
elif mode == "pack":
	hex_pack(sys.argv[2:])
