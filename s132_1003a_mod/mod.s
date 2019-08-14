.nds


.open "../inputbin/s132_nrf52_1.0.0-3.alpha_softdevice.hex_unpacked_00003000.bin","mod.bin",0x3000

.thumb

; .org 0x3000
; 	.word send_packet

.org 0xD2EA
	sub_D2EA:

.org 0x77E2
	ble_gatts_packet_handler_wrapper:

.org 0xD632
	bl sub_D624_hook

.org 0xD72c
	; disable code that send l2cap connection parameter update request
	bl l2cap_connupdatereq_hook

.org 0xDCBC
	sub_DCBC:

.org 0x12542
	radio_set_packetptr:

.org 0x1AC0E
	bl ble_radio_finish_sending_packet_hook

.org 0x1D900
	ble_radio_finish_sending_packet_hook:
		.word 0x1053f890; ldrb.w r1, [r0, #0x53]
		cmp r1, #0
		bne ble_radio_finish_sending_packet_hook_ret
		push {r0-r7,lr}
		; TODO: grab r1 (length) from r0, and adjust r1 probably
		
		; check that we have custom app firmware
		ldr r2, =0x21FDF
		ldrb r2, [r2]
		cmp r2, #0
		beq ble_radio_finish_sending_packet_hook_ret

		mov r1, #0x20
		ldr r2, =0x2000BFF0
		ldr r2, [r2]
		cmp r2, #0
		beq ble_radio_finish_sending_packet_hook_ret
		add r1, #3
		blx r2
		ble_radio_finish_sending_packet_hook_ret:
		pop {r0-r7,pc}

	.pool

	sub_D624_hook:
		; this is immediately after the call to sub_B924
		; start by doing the instructions we overwrote
		ldrh r5, [r3, #8]
		sub r4, #4
		push {r0-r7, lr}
		
		; check that we have custom app firmware
		ldr r4, =0x21FDF
		ldrb r4, [r4]
		cmp r4, #0
		beq sub_D624_hook_ret

		; be careful to preserve r1 and r2 since those are passed along to the callback directly
		ldr r4, =0x2000BFF4
		ldr r4, [r4]
		cmp r4, #0
		beq sub_D624_hook_ret
		mov lr, r4
		mov r0, r3
		add r0, #3
		; r1 already contains length at this point
		add r1, #7
		; r2 already contains first arg too actually, yay?
		ldr r3, =(send_packet | 1)
		blx lr
		; we check the return value of the callback: if 0 we just continue executing as normal, else we skip the rest of the function by jumping to 0xD5F8
		cmp r0, #0
		beq sub_D624_hook_ret
		ldr r0, =0xD5F9
		str r0, [sp, #4]
		sub_D624_hook_ret:
		pop {r0-r7, pc}

	.pool

	send_packet:
		; pass a3 through r0
		; r1, r2: buffer, length
		push {r0, r1, r2, r3, r4, r5, lr}
		sub sp, sp, #0x40

		; sub_D260(*(_WORD *)(v5 + 2), v7, 1, 4, out_packet_len, (int)&v13);

		; fill packet...
		add r1, sp, #0x18
		add r1, #2
		ldr r2, [sp, #0x44]
		ldr r3, [sp, #0x48]
		cmp r3, #0
		beq copy_loop_end
		copy_loop:
			ldrb r0, [r2]
			strb r0, [r1]
			add r1, #1
			add r2, #1
			sub r3, #1
			bne copy_loop
		copy_loop_end:

		ldr r0, [sp, #0x40]
		ldrh r0, [r0, #2]

		add r1, sp, #0x10
		str r1, [sp]
		mov r1, #1
		mov r2, #4
		ldr r3, [sp, #0x48]
		bl sub_D2EA

		; add sp, #0x40
		; pop {r0, r1, r2, r3, r4, r5, pc}

		add sp, #0x44
		pop {r1, r2, r3, r4, r5, pc}

	.pool

	l2cap_connupdatereq_hook:
		; r5 is saved on the stack but isn't used by the function we're hooking into after we return, so we can safely use it here
		ldr r5, =0x21FDF
		ldrb r5, [r5]
		cmp r5, #0
		beq enable_connupdatereq
		ldr r5, =0x2000BFF4
		ldr r5, [r5]
		cmp r5, #0
		bne disable_connupdatereq
		enable_connupdatereq:
		ldr r5, =0xD261
		bx r5
		disable_connupdatereq:
		mov r0, #0
		bx lr

	.pool


.Close
