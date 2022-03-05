.586
.model flat, stdcall
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;includem biblioteci, si declaram ce functii vrem sa importam
includelib msvcrt.lib
extern exit: proc
extern malloc: proc
extern memset: proc
extern printf: proc

includelib canvas.lib
extern BeginDrawing: proc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;declaram simbolul start ca public - de acolo incepe executia
public start
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;sectiunile programului, date, respectiv cod
.data
;aici declaram date
window_title DB "Snake",0
area_width EQU 640
area_height EQU 520
area DD 0

debug db "OKKKK %d %d", 13, 10, 0
stonks db "Stonks", 13, 10, 0

counter DD 0 ; numara evenimentele de tip timer

arg1 EQU 8
arg2 EQU 12
arg3 EQU 16
arg4 EQU 20

symbol_width EQU 10
symbol_height EQU 20

wall_width dd 40
wall_height dd 40

level_lin dd 12
level_col dd 16

level_pos_x dd 0
level_pos_y dd 0

level dd 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1
	  dd 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
	  dd 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
	  dd 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0
	  dd 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1
	  dd 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1


is_dead dd 0
is_pause dd 0
	  
body struct
	x dd 0
	y dd 0
	next dd 0
body ends

head body {3, 3, 0}
tail0 body {2, 3, offset head}
tail1 body {1, 3, offset tail0}
tail2 body {0, 3, offset tail1}

pointer_tail dd offset tail2

aux body {0, 0, 0}
;moving directions
right equ 0
down equ 1
left equ 2
up equ 3

curr_dir dd 0

food struct
	x dd 0
	y dd 0
	color dd 0
food ends

curr_food food {7, 3, 0ffffffh}

food_x dd 0
food_y dd 0

food_timer dd 0

score dd 0

include digits.inc
include letters.inc

.code
; procedura make_text afiseaza o litera sau o cifra la coordonatele date
; arg1 - simbolul de afisat (litera sau cifra)
; arg2 - pointer la vectorul de pixeli
; arg3 - pos_x
; arg4 - pos_y
make_text proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1] ; citim simbolul de afisat
	cmp eax, 'A'
	jl make_digit
	cmp eax, 'Z'
	jg make_digit
	sub eax, 'A'
	lea esi, letters
	jmp draw_text
make_digit:
	cmp eax, '0'
	jl make_space
	cmp eax, '9'
	jg make_space
	sub eax, '0'
	lea esi, digits
	jmp draw_text
make_space:	
	mov eax, 26 ; de la 0 pana la 25 sunt litere, 26 e space
	lea esi, letters
	
draw_text:
	mov ebx, symbol_width
	mul ebx
	mov ebx, symbol_height
	mul ebx
	add esi, eax
	mov ecx, symbol_height
bucla_simbol_linii:
	mov edi, [ebp+arg2] ; pointer la matricea de pixeli
	mov eax, [ebp+arg4] ; pointer la coord y
	add eax, symbol_height
	sub eax, ecx
	mov ebx, area_width
	mul ebx
	add eax, [ebp+arg3] ; pointer la coord x
	shl eax, 2 ; inmultim cu 4, avem un DWORD per pixel
	add edi, eax
	push ecx
	mov ecx, symbol_width
bucla_simbol_coloane:
	cmp byte ptr [esi], 0
	je simbol_pixel_alb
	mov dword ptr [edi], 0
	jmp simbol_pixel_next
simbol_pixel_alb:
	mov dword ptr [edi], 0FFFFFFh
simbol_pixel_next:
	inc esi
	add edi, 4
	loop bucla_simbol_coloane
	pop ecx
	loop bucla_simbol_linii
	popa
	mov esp, ebp
	pop ebp
	ret
make_text endp

; un macro ca sa apelam mai usor desenarea simbolului
make_text_macro macro symbol, drawArea, x, y
	push y
	push x
	push drawArea
	push symbol
	call make_text
	add esp, 16
endm

;arg1 - frame buffer
;arg2 - pos_x
;arg3 - pos_y
;arg4 - color
make_wall proc
	push ebp
	mov ebp, esp
	pusha
	
	mov edi, [ebp + arg1]
	mov eax, [ebp + arg3]
	mov ecx, area_width
	mul ecx
	mov ebx, [ebp + arg2]
	add eax, ebx
	shl eax, 2
	add edi, eax
	
	;mov dword ptr [edi], 0ffffffh
	
	xor ecx, ecx
	xor ebx, ebx
	l_linii:
		
		xor ebx, ebx
		l_coloane:
			push edi
			mov eax, ecx
			mov esi, area_width
			mul esi
			add eax, ebx
			shl eax, 2
			add edi, eax
			mov eax, [ebp + arg4]
			mov [edi], eax
			pop edi
		inc ebx
		mov edx, wall_height
		cmp ebx, edx
		jne l_coloane
	inc ecx
	mov edx, wall_width
	cmp ecx, edx
	jne l_linii
		
final_make_wall:
	popa
	mov esp, ebp
	pop ebp
	ret
make_wall endp

make_wall_macro macro draw_area, x, y, color

	push color
	push y
	push x
	push draw_area
	call make_wall
	add esp, 16
	
endm

blit_walls proc
	push ebp
	mov ebp, esp
	pusha

	xor ecx, ecx
	mov esi, 192
	xor ebx, ebx
	
	et1:
		mov eax, level[4 * ecx]
		cmp eax, 0
		je no_wall
		
		mov eax, ecx
		xor edx, edx
		div level_col
		mov ebx, edx
		xor edx, edx
		mul wall_width
		mov level_pos_y, eax
		mov eax, ebx
		xor edx, edx
		mul wall_width
		mov level_pos_x, eax
		
		make_wall_macro area, level_pos_x, level_pos_y, 0ffh
		
	
	no_wall:
	inc ecx
	cmp ecx, esi
	jne et1
	

final_blit_walls:
	popa
	mov esp, ebp
	pop ebp
	ret
blit_walls endp

blit_head proc
	push ebp
	mov ebp, esp
	pusha
	
	mov ecx, head.x
	mov ebx, head.y
	
	xor edx, edx
	mov eax, wall_width
	mul ecx
	mov level_pos_x, eax
	
	xor edx, edx
	mov eax, wall_width
	mul ebx
	mov level_pos_y, eax
	
	make_wall_macro area, level_pos_x, level_pos_y, 0ff00h
	
	
final_blit_head:
	popa
	mov esp, ebp
	pop ebp
	ret
blit_head endp

update_head_pos proc
	push ebp
	mov ebp, esp
	pusha
	
	mov ebx, curr_dir
	
	cmp ebx, right
	je update_right
	cmp ebx, down
	je update_down
	cmp ebx, left
	je update_left
	cmp ebx, up
	je update_up
	
	update_right:
		mov eax, head.x
		cmp eax, 15
		jne no_margin_right
		
		mov eax, 0
		mov head.x, eax
		jmp final_update_head_pos
		
		no_margin_right:
		inc head.x
		jmp final_update_head_pos
	update_down:
		mov eax, head.y
		cmp eax, 11
		jne no_margin_down
		
		mov eax, 0
		mov head.y, eax
		jmp final_update_head_pos
		
		no_margin_down:
		inc head.y
		jmp final_update_head_pos
	update_left:
		mov eax, head.x
		cmp eax, 0
		jne no_margin_left
		
		mov eax, 15
		mov head.x, eax
		jmp final_update_head_pos
		
		no_margin_left:
		dec head.x
		jmp final_update_head_pos
	update_up:
		mov eax, head.y
		cmp eax, 0
		jne no_margin_up
		
		mov eax, 11
		mov head.y, eax
		jmp final_update_head_pos
		
		no_margin_up:
		dec head.y
		jmp final_update_head_pos
	
final_update_head_pos:
	popa
	mov esp, ebp
	pop ebp
	ret
update_head_pos endp

update_death_state proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, head.x
	mov ebx, head.y
	
	mov esi, pointer_tail
	
	check_tail_collide:
		mov ecx, [esi]
		mov edx, [esi + 4]
		cmp eax, ecx
		jne no_tail_collide
		cmp ebx, edx
		jne no_tail_collide
		mov eax, 1
		mov is_dead, eax
		jmp final_update_death_state
	no_tail_collide:	
	mov esi, [esi + 8]
	cmp esi, offset head
	jne check_tail_collide
	
	
final_update_death_state:
	popa
	mov esp, ebp
	pop ebp
update_death_state endp

update_wall_collide proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, head.x
	mov ebx, head.y
	
	mov esi, level
	xor ecx, ecx
	
	check_wall_collide:
		mov edx, level[ecx * 4]
		cmp edx, 1
		jne no_wall_collide
		
		xor edx, edx
		mov eax, ecx
		mov ebx, level_col
		div ebx
		
		cmp eax, head.y
		jne no_wall_collide
		cmp edx, head.x
		jne no_wall_collide
		
		mov eax, 1
		mov is_dead, eax
		
		jmp final_update_wall_collide
		
	no_wall_collide:
	inc ecx
	cmp ecx, 192
	jne check_wall_collide
	
final_update_wall_collide:
	popa
	mov esp, ebp
	pop ebp
update_wall_collide endp

blit_body proc
	push ebp
	mov ebp, esp
	pusha
	
	mov esi, pointer_tail
	
	et_blit:
		mov ebx, [esi]
		mov ecx, [esi + 4]
		
		xor edx, edx
		mov eax, wall_width
		mul ebx
		mov level_pos_x, eax
		
		xor edx, edx
		mov eax, wall_width
		mul ecx
		mov level_pos_y, eax
		
		make_wall_macro area, level_pos_x, level_pos_y, 0ff99h
		
		mov esi, [esi + 8]
	
	cmp esi, offset head
	jne et_blit
	
final_blit_body:	
	popa
	mov esp, ebp
	pop ebp
	ret
blit_body endp

update_body_pos proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, pointer_tail
	
	et1:
		mov ebx, [eax + 8]
		mov ecx, [ebx]
		mov dword ptr [eax], ecx
		mov ecx, [ebx + 4]
		mov dword ptr [eax + 4], ecx
		mov eax, ebx
		
	cmp eax, offset head
	jne et1
	
	
final_update_body_pos:
	popa
	mov esp, ebp
	pop ebp
	ret
update_body_pos endp

increase_body proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, 12
	
	push eax
	call malloc
	add esp, 4
	
	mov dword ptr [eax], 20
	mov dword ptr [eax + 4], 20
	mov ebx, pointer_tail
	mov dword ptr [eax + 8], ebx
	
	mov pointer_tail, eax
	
final_increase_body:
	popa
	mov esp, ebp
	pop ebp
	ret
increase_body endp

blit_food proc
	push ebp
	mov ebp, esp
	pusha

	mov ebx, curr_food.x
	mov ecx, curr_food.y
	
	xor edx, edx
	mov eax, wall_width
	mul ebx
	mov level_pos_x, eax
	
	xor edx, edx
	mov eax, wall_width
	mul ecx
	mov level_pos_y, eax
	
	make_wall_macro area, level_pos_x, level_pos_y, 0ffffffh
		
final_blit_food:
	popa
	mov esp, ebp
	pop ebp
	ret
blit_food endp

update_food proc
	push ebp
	mov ebp, esp
	pusha

	mov eax, food_timer
	cmp eax, 15
	je pick_again
	
	mov eax, curr_food.x
	mov ebx, curr_food.y
	
	cmp eax, head.x
	jne final_update_food
	cmp ebx, head.y
	jne final_update_food
	
	call increase_body
	inc score
	jmp pick_again

boom:
	
	push offset stonks
	call printf
	add esp, 4
	
pick_again:

	xor eax, eax
	mov food_timer, eax
	
	rdtsc
	xor edx, edx
	mov ecx, level_lin
	div ecx
	
	mov food_y, edx
	
	rdtsc
	xor edx, edx
	mov ecx, level_col
	div ecx
	
	mov food_x, edx
	
	push food_y
	push food_x
	push offset debug
	call printf
	add esp, 12
	
	mov esi, pointer_tail
	
	parc_corp:
		mov ebx, [esi]
		mov ecx, [esi + 4]
		cmp ebx, food_x
		jne no_tail
		cmp ecx, food_y			
		je pick_again
	
	no_tail:
	mov esi, [esi + 8]
	cmp esi, 0
	jne parc_corp
	
	xor edx, edx
	mov eax, food_y
	mov ebx, level_col
	mul ebx
	
	add eax, food_x
	cmp level[eax * 4], 1
	je pick_again
	
	mov eax, food_x
	mov curr_food.x, eax
	
	mov ebx, food_y
	mov curr_food.y, ebx
	
	
final_update_food:
	popa
	mov esp, ebp
	pop ebp
	ret
	
update_food endp

reset proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, offset tail2
	mov pointer_tail, eax
	
	mov eax, 3
	mov head.x, eax
	mov head.y, eax
	
	mov eax, 2
	mov tail0.x, eax
	mov eax, 3
	mov tail0.y, eax
	mov eax, offset head
	mov tail1.next, eax
	
	mov eax, 1
	mov tail1.x, eax
	mov eax, 3
	mov tail1.y, eax
	mov eax, offset tail0
	mov tail1.next, eax
	
	mov eax, 0
	mov tail2.x, eax
	mov eax, 3
	mov tail2.y, eax
	mov eax, offset tail1
	mov tail2.next, eax
	
	mov eax, right
	mov curr_dir, eax

	mov eax, 0
	mov is_dead, eax
	
	mov eax, 0
	mov score, 0
	
final_reset:
	popa
	mov esp, ebp
	pop ebp
	ret
reset endp

; functia de desenare - se apeleaza la fiecare click
; sau la fiecare interval de 200ms in care nu s-a dat click
; arg1 - evt (0 - initializare, 1 - click, 2 - s-a scurs intervalul fara click, 3 - s-a apasat o tasta)
; arg2 - x (in cazul apasarii unei taste, x contine codul ascii al tastei care a fost apasata)
; arg3 - y
draw proc
	push ebp
	mov ebp, esp
	pusha
	
	mov eax, [ebp+arg1]
	cmp eax, 2
	jz evt_timer ; nu s-a efectuat click pe nimic
	
	; cmp eax, 3
	; jz evt_press
	;mai jos e codul care intializeaza fereastra cu pixeli albi
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	push 255
	push area
	call memset
	add esp, 12
	
evt_press:
	
	mov eax, [ebp + arg2]
	cmp eax, 050h
	jne check_restart
	mov ebx, is_pause
	cmp ebx, 0
	jne yes_pause
	mov eax, 1
	mov is_pause, eax
	jmp alive
	
	yes_pause:
	mov eax, 0
	mov is_pause, eax
	
	check_restart:
	mov ebx, is_dead
	cmp ebx, 1
	jne alive
	mov eax, [ebp + arg2]
	cmp eax, 052h
	jne alive
	call reset
	jmp clear
	
	alive:
	mov ebx, curr_dir
	mov eax, [ebp + arg2]
	cmp eax, 044h  
	je dir_right
	cmp eax, 053h  
	je dir_down
	cmp eax, 041h  
	je dir_left
	cmp eax, 057h  
	je dir_up
	
	
	
	dir_right:
		mov ecx, right
		cmp ebx, left
		je dir_final
		mov curr_dir, ecx
		jmp dir_final
	dir_down:
		mov ecx, down
		cmp ebx, up
		je dir_final
		mov curr_dir, ecx
		jmp dir_final
	dir_left:
		mov ecx, left
		cmp ebx, right
		je dir_final
		mov curr_dir, ecx
		jmp dir_final
	dir_up:
		mov ecx, up
		cmp ebx, down
		je dir_final
		mov curr_dir, ecx
		jmp dir_final
	
dir_final:
	jmp clear
	
evt_timer:
	
	mov eax, 1
	cmp  is_pause, eax
	je pauza
	
	mov eax, 1
	cmp is_dead, eax 
	je dead
	
	inc food_timer
	
	call update_wall_collide
	call update_death_state
	mov eax, 1
	cmp is_dead, eax 
	je dead
	call update_food
	call update_body_pos
	call update_head_pos

	clear:
		mov edi, area
		mov ecx, 480
		
		bucla_linii:
			xor eax, eax
			push ecx
			mov ecx, area_width
			bucla_coloane:
				mov [edi], eax
				add edi, 4
				loop bucla_coloane
			pop ecx
			loop bucla_linii
		
		mov edi, area
		add edi, 640 * 480 * 4
		mov ecx, 640 * 40
		
		mov eax, 0333333h
		score_clear:
			mov [edi], eax
			add edi, 4
		loop score_clear
		
	call blit_walls
	call blit_food
	call blit_head
	call blit_body
	
	mov ebx, 10
	mov eax, score
	;cifra unitatilor
	xor edx, edx
	div ebx
	add edx, '0'
	make_text_macro edx, area, 30, 490
	;cifra zecilor
	xor edx, edx
	div ebx
	add edx, '0'
	make_text_macro edx, area, 20, 490
	;cifra sutelor
	xor edx, edx
	div ebx
	add edx, '0'
	make_text_macro edx, area, 10, 490
	
	jmp final_draw
	
	dead:
		make_text_macro 'M', area, 290, 100
		make_text_macro 'O', area, 300, 100
		make_text_macro 'R', area, 310, 100
		make_text_macro 'T', area, 320, 100
		jmp final_draw
	
	pauza:
		make_text_macro 'P', area, 290, 100
		make_text_macro 'A', area, 300, 100
		make_text_macro 'U', area, 310, 100
		make_text_macro 'Z', area, 320, 100
		make_text_macro 'A', area, 330, 100
		jmp final_draw
	
final_draw:
	popa
	mov esp, ebp
	pop ebp
	ret
draw endp

start:
	;alocam memorie pentru zona de desenat
	
	mov eax, area_width
	mov ebx, area_height
	mul ebx
	shl eax, 2
	push eax
	call malloc
	add esp, 4
	mov area, eax
	;apelam functia de desenare a ferestrei
	; typedef void (*DrawFunc)(int evt, int x, int y);
	; void __cdecl BeginDrawing(const char *title, int width, int height, unsigned int *area, DrawFunc draw);
	push offset draw
	push area
	push area_height
	push area_width
	push offset window_title
	call BeginDrawing
	add esp, 20
	
	;terminarea programului
	push 0
	call exit
end start
