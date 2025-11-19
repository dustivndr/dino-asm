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

; 	mov qword [score], 0
; 	mov dword [cactus_x], 30
; 	mov dword [jump_timer], 0

