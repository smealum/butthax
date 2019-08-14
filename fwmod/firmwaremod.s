.nds

.open "../inputbin/hushfw.bin","firmwaremod.bin",0x1f000

.thumb

UART_INCOMING_STRING equ 0x20002E18

.org 0x1F5D2
	memcmp:

.org 0x1F58A
	memcpy:

.org 0x204ec
	SYSRESETREQ:

.org 0x2107E
	sendUartResponse_:

.org 0x210FC
	bl buttonPressCallback_hook

.org 0x2111C
	plugDoPresetPatterns:

; .org 0x21AE0
; 	bl start_hook

.org 0x21cd2
	bl start_hook

.org 0x21FDF
	; so that the softdevice knows this is modded (yes this is janky but who cares this is a buttplug custom firmware)
	.byte 0x01


; .org 0x21D60
; 	bl serialCommandHandler_hook

; r1: buffer, r2: length
.macro sendUartResponse
	ldr r0, =0x20002E2C
	bl sendUartResponse_
.endmacro

.org 0x23C00
	start_hook:
		; instructions we overwrote (gpioClearPin)
		mov r1, #1
		lsl r1, r0
		ldr r0, =0x5000050c
		str r1, [r0]

		push {lr}
		bl patch_softdevice

		; initialize exploit blob
		ldr r0, =exploit_start
		ldr r1, [r0]
		blx r1

		; ; initialize ble hooks
		; ldr r0, =0x2000BFF0
		; mov r1, #0
		; str r1, [r0]
		; str r1, [r0, #4]

		; initialize ble hooks
		ldr r0, =0x2000BFF0
		ldr r1, =exploit_start
		ldr r2, [r1, #4]
		str r2, [r0]
		ldr r2, [r1, #8]
		str r2, [r0, #4]

		pop {pc}

	buttonPressCallback_hook:
		push {r0, lr}
		; on preset 5 we want to disable the exploit
		; TODO: make it be a toggle instead? can just reboot anyway so might be easier as-is

		cmp r0, #5
		bne buttonPressCallback_hook_skip
		; re-initialize ble hooks
		ldr r0, =0x2000BFF0
		mov r1, #0
		str r1, [r0]
		str r1, [r0, #4]

		buttonPressCallback_hook_skip:
		pop {r0}
		bl plugDoPresetPatterns
		pop {pc}

	serialCommandHandler_hook:
		push {r0-r3,lr}
		ldr r0, =UART_INCOMING_STRING
		add r1, =read_cmd
		mov r2, #(read_cmd_end - read_cmd)
		bl memcmp
		cmp r0, #0
		bne serialCommandHandler_hook_notread
			; read command!
			ldr r0, =(UART_INCOMING_STRING + read_cmd_end - read_cmd)
			bl read_hex
			ldr r1, [r0]
			sub sp, #0x10
			ldr r0, =0x3A54554F
			str r0, [sp]
			add r0, sp, #4
			bl write_hex
			mov r1, sp
			mov r2, #0xC
			sendUartResponse
			add sp, #0x10
			b serialCommandHandler_hook_notwrite
		serialCommandHandler_hook_notread:
		ldr r0, =UART_INCOMING_STRING
		add r1, =write_cmd
		mov r2, #(write_cmd_end - write_cmd)
		bl memcmp
		cmp r0, #0
		bne serialCommandHandler_hook_notwrite
			; write command!
			ldr r0, =(UART_INCOMING_STRING + write_cmd_end - write_cmd)
			bl read_hex
			push {r0}
			ldr r0, =(UART_INCOMING_STRING + write_cmd_end - write_cmd + 9)
			bl read_hex
			mov r1, r0
			pop {r0}
			str r1, [r0]
			sub sp, #0x10
			ldr r0, =0x454E4F44
			mov r1, sp
			mov r2, #0x4
			sendUartResponse
			add sp, #0x10
		serialCommandHandler_hook_notwrite:
		pop {r0-r3}
		bl memcmp
		pop {pc}

	; r0: hex word string address
	read_hex:
		mov r3, #0
		mov r1, #8
		read_hex_loop:
			ldrb r2, [r0]
			sub r2, #0x30
			lsl r3, #4
			orr r3, r2
			add r0, #1
			sub r1, #1
			bne read_hex_loop
		mov r0, r3
		bx lr

	; r0: hex word string address
	; r1: hex word value
	write_hex:
		mov r2, #8
		write_hex_loop:
			mov r3, r1
			lsl r3, #28
			lsr r3, #28
			add r3, #0x30
			strb r3, [r0]
			lsr r3, #4
			add r0, #1
			sub r2, #1
			bne write_hex_loop
		bx lr

.align 4
read_cmd:
	.ascii "READ:"
read_cmd_end:

.align 4
write_cmd:
	.ascii "WRITE:"
write_cmd_end:

.pool

; define some constants
NVMC equ 0x4001E000
NVMC_READY equ (NVMC + 0x400) ; Busy = 0, Ready = 1
NVMC_CONFIG equ (NVMC + 0x504) ; Ren = 0, Wen = 1, Een = 2
NVMC_ERASEPAGE equ (NVMC + 0x508)

TEMP_PAGE_BUFFER equ (0x2000C000)

; nvmc helper functions
	; no parameters
	; for convenience, preserves all registers
	nvmc_wait_ready:
		push {r0,r1,lr}
		ldr r0, =NVMC_READY
		nvmc_wait_ready_loop:
			ldr r1, [r0]
			cmp r1, 1
			bne nvmc_wait_ready_loop
		pop {r0,r1,pc}

	; r0: page address
	nvmc_page_erase:
		push {lr}

		; set NVMC_CONFIG to allow erasing
		ldr r3, =NVMC_CONFIG
		mov r2, #2 ; WEN_Een
		str r2, [r3]

		; wait for operation to be done
		bl nvmc_wait_ready

		; set which page to erase
		str r0, [r3, #NVMC_ERASEPAGE - NVMC_CONFIG]

		; wait for operation to be done
		bl nvmc_wait_ready

		; reset config to read-only
		; (we may be able to remove this since we'll be going to write mode afterwards anyway)
		mov r2, #0 ; WEN_Ren
		str r2, [r3]

		; wait for operation to be done
		bl nvmc_wait_ready
		
		pop {pc}

	; r0: target address
	; r1: source data
	; r2: source data length (MUST be multiple of 4)
	nvmc_write:
		push {r4,lr}
		
		; set NVMC_CONFIG to allow erasing
		ldr r4, =NVMC_CONFIG
		mov r3, #1 ; WEN_Wen
		str r3, [r4]

		; wait for operation to be done
		bl nvmc_wait_ready

		nvmc_write_loop:
			; write words
			ldr r3, [r1]
			str r3, [r0]
			; wait for operation to be done
			bl nvmc_wait_ready
			add r0, #4
			add r1, #4
			sub r2, #4
			bne nvmc_write_loop

		; reset config to read-only
		mov r3, #0 ; WEN_Ren
		str r3, [r4]

		; wait for operation to be done
		bl nvmc_wait_ready
		
		pop {r4,pc}

	patch_softdevice:
		.include "patchsoftdevice.s"

	.pool

.org 0x00025000
	exploit_start:
	.incbin "exploit/exploit.bin"

.Close
