; Dino game in 32-bit Linux NASM using int 0x80
; Controls: press SPACE to jump. Avoid the cactus. Score +1 for each successful jump.
; Build: nasm -f elf32 dino.asm -o dino.o && ld -m elf_i386 dino.o -o dino

%define STDIN          0
%define STDOUT         1

%define SYS_EXIT       1
%define SYS_READ       3
%define SYS_WRITE      4
%define SYS_IOCTL      54
%define SYS_SELECT     142
%define SYS_NANOSLEEP  162

%define TCGETS         0x5401
%define TCSETS         0x5402

%define ICANON         0x0002
%define ECHO           0x0008
%define ISIG           0x0001

%define WIDTH          32              ; playfield columns
%define DINO_COL       0               ; fixed dino column
%define JUMP_FRAMES    5               ; frames the dino stays in the air
%define FRAME_NS       80000000        ; 80 ms per frame
%define SPAWN_BASE     (WIDTH + 10)    ; cactus respawn base distance
%define SPAWN_SPREAD   12              ; extra random distance 0..11

section .data
	esc_clear       db 0x1b, "[2J", 0x1b, "[H"
	esc_clear_len   equ $ - esc_clear

	ground_line:
		times WIDTH db '='
		db 10
	ground_len      equ $ - ground_line

	score_label     db "score: "
	score_label_len equ $ - score_label

	game_over_msg   db "GAME OVER! Final score: "
	game_over_len   equ $ - game_over_msg

	linefeed        db 10

	frame_ts        dd 0, FRAME_NS     ; struct timespec {sec, nsec}
	zero_timeval    dd 0, 0            ; struct timeval {sec, usec}

	dino_char       db 'D'
	cactus_char     db '#'
	space_char      db ' '

section .bss
	term_orig       resb 60            ; original termios
	term_raw        resb 60            ; modified termios

	fdset           resb 128           ; fd_set for select
	input_char      resb 1

	line_buf        resb WIDTH + 1     ; render buffer + newline
	score_buf       resb 4             ; 4-digit score

	score           resd 1
	cactus_x        resd 1
	jump_timer      resd 1
	rand_seed       resd 1

section .text
	global _start

; ---------------------------
; sys_write wrapper: write(fd=STDOUT, buf, len)
; ---------------------------
write_stdout:
	mov eax, SYS_WRITE
	mov ebx, STDOUT
	int 0x80
	ret

; ---------------------------
; sys_exit wrapper
; ---------------------------
exit_clean:
	mov eax, SYS_EXIT
	int 0x80

; ---------------------------
; set terminal to raw (non-canonical, no echo)
; ---------------------------
set_terminal_raw:
	; fetch current termios
	mov eax, SYS_IOCTL
	mov ebx, STDIN
	mov ecx, TCGETS
	lea edx, [term_orig]
	int 0x80

	; copy term_orig -> term_raw (60 bytes / 15 dwords)
	mov ecx, 15
	mov esi, term_orig
	mov edi, term_raw
	rep movsd

	; clear ICANON | ECHO | ISIG in c_lflag (offset 12)
	and dword [term_raw + 12], ~(ICANON | ECHO | ISIG)

	; apply raw settings
	mov eax, SYS_IOCTL
	mov ebx, STDIN
	mov ecx, TCSETS
	lea edx, [term_raw]
	int 0x80
	ret

; ---------------------------
; restore terminal settings
; ---------------------------
restore_terminal:
	mov eax, SYS_IOCTL
	mov ebx, STDIN
	mov ecx, TCSETS
	lea edx, [term_orig]
	int 0x80
	ret

; ---------------------------
; clear screen
; ---------------------------
clear_screen:
	lea ecx, [esc_clear]
	mov edx, esc_clear_len
	call write_stdout
	ret

; ---------------------------
; nanosleep for one frame
; ---------------------------
sleep_frame:
	mov eax, SYS_NANOSLEEP
	lea ebx, [frame_ts]
	xor ecx, ecx
	int 0x80
	ret

; ---------------------------
; poll stdin for a single char without blocking
; returns AL = 1 if space was read, else 0
; ---------------------------
poll_space:
	; zero fdset (128 bytes)
	mov ecx, 128 / 4
	mov edi, fdset
	xor eax, eax
.zero_loop:
	mov dword [edi], eax
	add edi, 4
	dec ecx
	jnz .zero_loop

	; set bit for fd 0
	mov byte [fdset], 1

	; select(nfds=1, &fdset, NULL, NULL, &zero_timeval)
	mov eax, SYS_SELECT
	mov ebx, 1
	lea ecx, [fdset]
	xor edx, edx
	xor esi, esi
	lea edi, [zero_timeval]
	int 0x80
	cmp eax, 1
	jne .no_key

	; read one byte
	mov eax, SYS_READ
	mov ebx, STDIN
	lea ecx, [input_char]
	mov edx, 1
	int 0x80
	cmp eax, 1
	jne .no_key

	mov al, [input_char]
	cmp al, ' '
	sete al
	ret

.no_key:
	xor al, al
	ret

; ---------------------------
; build line into line_buf given positions
; in: EAX = dino position (or -1), EBX = cactus position (or -1)
; ---------------------------
build_line:
	push eax
	push ebx

	; fill spaces
	mov ecx, WIDTH
	lea edi, [line_buf]
	mov al, [space_char]
	rep stosb
	; newline at end
	mov byte [line_buf + WIDTH], 10

	; restore positions
	pop ebx
	pop eax

	; place dino if visible
	cmp eax, 0
	jl .skip_dino
	cmp eax, WIDTH
	jge .skip_dino
	mov byte [line_buf + eax], 'D'
.skip_dino:

	; place cactus if visible
	cmp ebx, 0
	jl .skip_cactus
	cmp ebx, WIDTH
	jge .skip_cactus
	mov byte [line_buf + ebx], '#'
.skip_cactus:
	ret

; ---------------------------
; write current score as 4 digits (zero padded)
; ---------------------------
write_score:
	mov eax, [score]
	mov ecx, 4
	lea edi, [score_buf + 4]
.digit_loop:
	xor edx, edx
	mov ebx, 10
	div ebx
	dec edi
	add dl, '0'
	mov [edi], dl
	dec ecx
	jnz .digit_loop

	lea ecx, [score_buf]
	mov edx, 4
	call write_stdout
	ret

; ---------------------------
; draw the entire scene
; ---------------------------
draw_scene:
	call clear_screen

	; top row: dino only if jumping
	mov eax, [jump_timer]
	cmp eax, 0
	jg .air_has_dino
	mov eax, -1
	jmp .air_done
.air_has_dino:
	mov eax, DINO_COL
.air_done:
	mov ebx, -1
	call build_line
	lea ecx, [line_buf]
	mov edx, WIDTH + 1
	call write_stdout

	; ground row: dino on ground if not jumping, cactus visible when in range
	mov eax, [jump_timer]
	cmp eax, 0
	jg .no_ground_dino
	mov eax, DINO_COL
	jmp .ground_dino_done
.no_ground_dino:
	mov eax, -1
.ground_dino_done:
	mov ebx, [cactus_x]
	call build_line
	lea ecx, [line_buf]
	mov edx, WIDTH + 1
	call write_stdout

	; ground line
	lea ecx, [ground_line]
	mov edx, ground_len
	call write_stdout

	; score line
	lea ecx, [score_label]
	mov edx, score_label_len
	call write_stdout
	call write_score
	mov ecx, linefeed
	mov edx, 1
	call write_stdout
	ret

; ---------------------------
; spawn cactus at random distance to the right
; ---------------------------
spawn_cactus:
	; simple PRNG using rdtsc + seed
	rdtsc
	xor eax, edx
	add eax, [rand_seed]
	mov [rand_seed], eax

	mov ebx, SPAWN_SPREAD
	xor edx, edx
	div ebx                 ; remainder in EDX (0..SPAWN_SPREAD-1)
	mov eax, SPAWN_BASE
	add eax, edx
	mov [cactus_x], eax
	ret

; ---------------------------
; game over screen
; ---------------------------
show_game_over:
	call clear_screen
	lea ecx, [game_over_msg]
	mov edx, game_over_len
	call write_stdout
	call write_score
	mov ecx, linefeed
	mov edx, 1
	call write_stdout
	ret

; ---------------------------
; program entry
; ---------------------------
_start:
	call set_terminal_raw

	; init state
	mov dword [score], 0
	mov dword [jump_timer], 0
	mov dword [rand_seed], 12345
	call spawn_cactus

main_loop:
	call draw_scene

	; handle input
	call poll_space
	cmp al, 1
	jne .no_jump_input
	cmp dword [jump_timer], 0
	jg .no_jump_input        ; already in air
	mov dword [jump_timer], JUMP_FRAMES
.no_jump_input:

	; move cactus left
	dec dword [cactus_x]

	; collision or success when cactus reaches dino column
	cmp dword [cactus_x], DINO_COL
	jne .after_collision

	cmp dword [jump_timer], 0
	jg .success
	jmp game_over

.success:
	inc dword [score]
.after_collision:

	; respawn cactus when off-screen
	cmp dword [cactus_x], -2
	jg .skip_spawn
	call spawn_cactus
.skip_spawn:

	; update jump timer
	cmp dword [jump_timer], 0
	jle .skip_jump_decr
	dec dword [jump_timer]
.skip_jump_decr:

	; wait for next frame
	call sleep_frame
	jmp main_loop

game_over:
	call show_game_over
	call restore_terminal
	xor ebx, ebx
	jmp exit_clean
