;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;           DINO ASM           ;
;       Simple Dino Game       ;
;         for fun only         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; NASM, x86-64, Linux ;

section _data

	esc_clear		db 0x1b, '[2J', 0x1b, '[H'
	esc_clear_len	equ $ - esc_clear

	ground_line		db '==============================', 10
	ground_len		equ $ -	ground_line

	dino_ground		db '  D', 10
	dino_jump		db '  D', 10
	space_nl		db 10

	prompt			db '(press <space> to jump)', 0
	prompt_len		equ $ - prompt

	gameover_msg	db 'GAME OVER! SCORE: '
	gameover_len	equ $ - gameover_msg

	newline 		db 10
	newline_len		equ $ - newline

	ts_half			dq 0, 120000000

section .bss

	input_buf 		resb 8

section .text

	global _start

write_sys:

	mov rax, 1
	syscall
	ret

read_sys:

	mov rax, 0
	syscall
	ret

nanosleep_sys:

	mov rax, 35
	syscall
	ret

_start:

	mov qword [score], 0
	mov dword [cactus_x], 30
	mov dword [jump_timer], 0

main_loop:

	mov rdi, 1
	lea rsi, [rel esc_clear]
	mov rdx, esc_clear_len
	call write_sys

	mov rdi, 1
	lea rsi, [rel space_nl]
	mov rdx, 1
	call write_sys

	mov eax, [jump_timer]
	cmp eax, 0
	jg .dino_jump

.dino_ground:

	mov rdi, 1
	lea rsi, [rel dino_ground]
	mov rdx, 4
	call write_sys
	jmp .draw_cactus

.dino_jump:

	mov rdi, 1
	lea rsi, [rel dino_jump]
	mov rdx, 4
	call write_sys

.draw_cactus:

	mov ecx, [cactus_x]
	cmp ecx, 0
	jl .no_cactus_print
	mov ebx, ecx

	cmp ebx, 0
	jle .print_cactus_char

.print_spaces_loop:

	mov rdi, 1
	lea rsi, [rel sp_char]
	mov rdx, 1
	call write_sys
	dec ebx
	jg .print_spaces_loop

.print_cactus_char:

	mov rdi, 1
	lea rsi, [rel cactus_char]
	mov rdx, 1
	call write_sys

	mov rdi, 1
	lea rsi, [rel newline]
	mov rdx, 1
	call write_sys
	jmp .after_cactus

.no_cactus_print:

	mov rdi, 1
	lea rsi, [rel newline]
	mov rdx, 1
	call write_sys

.after_cactus:

	mov rdi, 1
	lea rsi, [rel ground_line]
	mov rdx, ground_len
	call write_sys

	mov rdi, 1
	lea rsi, [rel score_msg]
	mov rdx, score_msg_len
	call write_sys

	mov rax, [score]
	call print_decimal

	mov rdi, 1
	lea rsi, [rel prompt]
	mov rdx, prompt_len
	call write_sys

	mov rdi, 0
	lea rsi, [rel input_buf]
	mov rdx, 8
	call read_sys
	mov rdi, rax

	mov al, byte [input_buf]
	cmp al, 0x20
	je .do_jump

	jmp .after_input

.do_jump:

	mov dword [jump_timer], 3

.after_input:

	dec dword [cactus_x]

	mov eax, [jump_timer]
	cmp eax, 0
	jle .no_decr
	dec dword [jump_timer]

.no_decr:

	inc qword [score]

	mov eax, [cactus_x]
	cmp eax, 0
	jg .continue_game
	mov ebx, [jump_timer]
	cmp ebx, 0
	jne .continue_game
	jmp .game_over

.continue_game:

	lea rdi, [rel ts_half]
	call nanosleep_sys

	mov eax, [cactus_x]
	cmp eax, -5
	jg .loop_continue
	mov dword [cactus_x], 30
	jmp .loop_continue

.loop_continue:

	jmp main_loop

.game_over:

	mov rdi, 1
	lea rsi, [rel esc_clear]
	mov rdx, esc_clear_len
	call write_sys

	mov rdi, 1
	lea rsi, [rel gameover_msg]
	mov rdx, gameover_len
	call write_sys

	mov rax, [score]
	call print_decimal

	mov rdi, 1
	lea rsi, [rel newline]
	mov rdx, 1
	call write_sys

	mov rax, 60
	xor rdi, rdi
	syscall

print_decimal:

	push rbp
	push rbx
	push rcx
	push rdx
	push rsi
	push rdi

	mov rcx, 0
	mov rbx, 10
; 	mov rsi, sp

	cmp rax, 0
	jne .pd_loop
	mov rdi, 1
	lea rsi, [rel zero_char]
	mov rdx, 1
	call write_sys
	jmp .pd_done

.pd_loop:

	xor rdx, rdx
	div rbx           ; rax/=10, rdx=remainder
	add dl, '0'
	push rdx
	inc rcx
	cmp rax, 0
	jne .pd_loop

.pd_pop_loop:

	cmp rcx, 0
	je .pd_done
	pop rdx
	mov byte [rsp-1], dl   ; place char (adjust stack slot)
	lea rsi, [rsp-1]
	mov rdi, 1
	mov rdx, 1
	call write_sys
	dec rcx
	jmp .pd_pop_loop

.pd_done:

	pop rdi
	pop rsi
	pop rdx
	pop rcx
	pop rbx
	pop rbp
	ret

section .data

	sp_char 		db ' '
	cactus_char 	db '#'
	zero_char 		db '0'

	score_msg 		db 'Score: '
	score_msg_len 	equ $ - score_msg

section .bss

	cactus_x   resd 1
	jump_timer resd 1
	score      resq 1
