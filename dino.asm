;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;         DINO ASM           ;
;     Simple Dino Game       ;
;       for fun only         ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; NASM, x86-64, Linux

section _data

	esc_clear      	db 0x1b, '[2J', 0x1b, '[H'
   	esc_clear_len	equ $ - esc_clear

	ground_line	db '==============================', 10
	ground_len	equ $ -	ground_line

	dino_ground	db '  D', 10
	dino_jump	db '  D', 10
	space_nl	db 10
