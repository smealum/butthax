.nds

; d1071
.create "donglehook.bin",0x1E3AC

; NOTE: last u32 in this file must be address of XSS data

.thumb
	ldr r0, [stradr]
	b poststradr
	stradr:
		.word 0x00036000
	poststradr:

.Close
