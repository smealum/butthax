import struct

origfn = r"C:\re\nordic\s132_1003a_mod\s132_nrf52_1.0.0-3.alpha_softdevice.hex_unpacked_00003000.bin"
newfn = r"C:\re\nordic\s132_1003a_mod\mod.bin"
baseaddr = 0x3000
pagesize = 0x1000

origdata = bytearray(open(origfn, "rb").read())
newdata = bytearray(open(newfn, "rb").read())

if (len(newdata) % pagesize) != 0:
	bytesmissing = pagesize - (len(newdata) % pagesize)
	newdata += bytearray(b"\xFF" * bytesmissing)

if len(origdata) < len(newdata):
	bytesmissing = len(newdata) - len(origdata)
	origdata += bytearray(b"\xFF" * bytesmissing)

filelength = len(origdata)

if filelength != len(newdata):
	print("files must be the same size")
	exit()

code_stream = ""
data_stream = ""

def add_code_line(line):
	global code_stream
	code_stream += line + "\n"

def prepend_code_line(line):
	global code_stream
	code_stream = line + "\n" + code_stream

def add_data_line(line):
	global data_stream
	data_stream += line + "\n"

last_chunk = ""
last_chunk_addr = ""
last_chunk_length = 0

for i in range(0, filelength, pagesize):
	origpage = origdata[i : i + pagesize]
	newpage = newdata[i : i + pagesize]

	if origpage != newpage:
		pageaddress = i + baseaddr
		origempty = True
		for j in origpage:
			if j != 0xFF:
				origempty = False
				break
		if not(origempty):
			add_code_line("ldr r0, =TEMP_PAGE_BUFFER")
			add_code_line("ldr r1, =0x%08X" % (pageaddress))
			add_code_line("ldr r2, =0x%04X" % (pagesize))
			add_code_line("bl memcpy\n")
		currently_same = (origpage[0] == newpage[0])
		last_change = 0
		allempty = True
		for j in range(0, pagesize, 4):
			origword = struct.unpack("<I", origpage[j : (j + 4)])[0]
			newword = struct.unpack("<I", newpage[j : (j + 4)])[0]
			if newword != 0xFFFFFFFF:
				allempty = False
			if (origword == newword) and not(currently_same):
				if not(allempty):
					chunkaddr = (pageaddress + last_change)
					chunkname = "chunk_0x%08X" % chunkaddr
					last_chunk = chunkname
					last_chunk_length = (j - last_change)
					last_chunk_addr = chunkaddr
					add_code_line("ldr r0, =(TEMP_PAGE_BUFFER + 0x%08X)" % (last_change))
					add_code_line("add r1, =%s" % chunkname)
					add_code_line("ldr r2, =0x%04X" % (j - last_change))
					add_code_line("bl memcpy\n")
					add_data_line(".align 4")
					add_data_line(chunkname + ":")
					add_data_line("\t.byte " + ", ".join(["0x%02X" % v for v in newpage[last_change:j]]))
				allempty = True
				currently_same = True
				last_change = j
			elif (origword != newword) and currently_same:
				allempty = True
				currently_same = False
				last_change = j
		if not(allempty):
			if not(currently_same):
				chunkaddr = (pageaddress + last_change)
				add_code_line("ldr r0, =(TEMP_PAGE_BUFFER + 0x%08X)" % (last_change))
				chunkname = "chunk_0x%08X" % chunkaddr
				last_chunk = chunkname
				last_chunk_length = (pagesize - last_change)
				last_chunk_addr = chunkaddr
				add_code_line("add r1, =%s" % chunkname)
				add_code_line("ldr r2, =0x%04X" % (pagesize - last_change))
				add_code_line("bl memcpy\n")
		if not(origempty):
			add_code_line("ldr r0, =0x%08X" % (pageaddress))
			add_code_line("bl nvmc_page_erase\n")
		add_code_line("ldr r0, =0x%08X" % (pageaddress))
		add_code_line("ldr r1, =TEMP_PAGE_BUFFER")
		add_code_line("ldr r2, =0x%04X" % (pagesize))
		add_code_line("bl nvmc_write\n")

add_code_line("bl SYSRESETREQ")
add_code_line(".halfword 0xb662 ; cpsie i")
add_code_line("patchsoftdevice_ret:")
add_code_line("pop {r0-r7,pc}\n")

if last_chunk != "" and last_chunk_length != 0:
	prepend_code_line(".halfword 0xb672 ; cpsid i\n")

	prepend_code_line("beq patchsoftdevice_ret\n")
	prepend_code_line("cmp r0, r1")
	prepend_code_line("ldr r1, [r1]")
	prepend_code_line("ldr r1, =0x%08X" % (last_chunk_addr + last_chunk_length - 4))
	prepend_code_line("ldr r0, [r0]")
	prepend_code_line("add r0, =(%s + 0x%04X)" % (last_chunk, last_chunk_length - 4))

prepend_code_line("push {r0-r7,lr}")

print(code_stream)
print(data_stream)
