section .text
 
 
; Принимает код возврата и завершает текущий процесс
exit:
    xor rax, rax
    mov     rax, 60                         ; номер системного вызова 'exit'
    xor     rdi, rdi    
    syscall 

; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax
    .loop:
        cmp byte [rdi + rax], 0
        je .retLength
        inc rax
        jmp .loop
    .retLength:
        ret

; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:
    push rdi ; 
    call string_length 
    pop rdi;
    mov rsi, rdi
    mov rdi, 1 ; stdout
    mov rdx, rax ; длина строки
    mov rax, 1 ; write
    syscall

    ret

; Принимает код символа и выводит его в stdout
print_char:
    push rdi     
    mov rsi, rsp        
    mov rdx, 1
    mov rax, 1 ; write
    mov rdi, 1   ; stdout 
    syscall
    pop rdi

    ret

; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rax, 1 ; write
    mov rdi, 1 ; stdout
    mov rsi, rsp
    mov byte [rsp], 0xA
    mov rdx, 1
    syscall
    ret

; Выводит беззнаковое 8-байтовое число в десятичном формате 
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint: 
    push rbx  ; 16      
    mov rax, rdi 
    mov rbx, 10 ; делитель
    mov rsi, rsp ; сохраняем указатель на строку
    sub rsp, 40   ; выделим место в стеке
    dec rsi
    mov byte [rsi], 0 ; указатель на нуль-терминированную строку
    .loopDiv:
        xor rdx, rdx
        div rbx ; делим на rbx
        add dl, '0' ; Переводим остаток в ASCII
        dec rsi
        mov byte [rsi], dl ; сохраняем остаток о деления
        test rax, rax
        jnz .loopDiv
    .outRes:
        mov rdi, rsi   ; передает указатель на строку
        push rdi
        call print_string
        pop rdi
        add rsp, 40
        pop rbx
        ret

; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    sub rsp, 8 ; выравниваем стек
    mov rax, rdi
    test rax, rax ; проверяем на знак
    jge .positive 
    neg rax   ; если отрицательный
    push rax 
    push rdi  
    mov rdi, '-'
    call print_char
    pop rdi
    pop rax
    .positive:
        mov rdi, rax
        call print_uint
        add rsp, 8 
        ret


; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
; rdi - на 1ую, rsi на 2ую
string_equals:
;    push rsi
;    push rdi
;    call string_length 
;   mov rdx, rax ; длина первой строки
;    mov rdi, rsi ; 
;    call string_length 
;    mov rcx, rax ; длина 2ой строки
;    pop rdi
;    pop rsi
;    xor rax, rax 
;    cmp rdx, rcx
;    jne .not_equal 
    .equal_loop:
        mov r11b, byte [rdi]      ; Загружаем байт из первой строки     
        cmp r11b, byte [rsi] 
        jne .not_equal 
        test r11b, r11b    
        jz .equal            
        inc rdi                 
        inc rsi                 
        jmp .equal_loop

    .equal:            
        mov rax, 1
    .not_equal:
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    push rdi   
    mov rdi, 0 ; stdin (0)  
    sub rsp, 1
    lea rsi, [rsp]    
    mov rdx, 1
    syscall
    mov al, [rsp] ; прочитанный символ в al                    
    pop rdi
    add rsp, 1               
    ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push rdi 
    push rsi
    mov rcx, 0
    mov rbx, rsi
;    mov rcx, 0
    test rbx, rsi
    jz .word_bigger
    .loop_spaces:
	sub rsp, 8
        call read_char
	add rsp, 8      
        cmp rax, 0x0          
        je .end
        cmp rax, 0x20
        je .loop_spaces
        cmp rax, 0x9   
        je .loop_spaces
        cmp rax, 0xA
        je .loop_spaces
        dec rbx
        cmp rbx, 0          ; проверяем, не превышен ли размер буфера
        jbe .word_bigger
        mov [rdi + rcx], al
        inc rcx ; Увеличиваем длину слова
        jmp .loop_spaces

    .end:
        dec rbx
        cmp rbx, 0          ; проверяем, не превышен ли размер буфера
        jbe .word_bigger
        mov byte [rdi + rcx], 0   ; Добавляем нуль-терминатор
        mov rdx, rcx         ; rdx = длина слова
        mov rax, rdi       
        pop rsi
        pop rdi
        ret
    .word_bigger:
        xor rax, rax          ; Ошибка: установка rax в 0
        pop rsi
        pop rdi
        ret



; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    push rbx
    xor rax, rax
    xor rdx, rdx ; счётчик
    .loop_digit:
        mov al, [rdi] ; байт из строки
        test al, al ; конца строки
        jz .end               
        sub al, '0' ; преобразование ASCII в число
        cmp al, 9  
        ja .end ; если больше '9', выходим    
        shl rax, 1 ; Умножаем на 2
        add rax, rax ; Умножаем на 10
        add rax, rbx ; добовляем новое число             
        inc  rdx             
        inc  rdi             
        jmp .loop_digit    
    .end:
        pop rbx
        ret 


; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:
    xor rax, rax         
    xor rdx, rdx
    xor r8, r8         
    mov rcx, rdi
    .skip_spaces:
        cmp byte [rcx], ' '  ; символ пробел
        je .skip_spaces       ; 
        cmp byte [rcx], 0     ;  конец строки
        je .end          
        cmp byte [rcx], '-'   
        je .negative           
        cmp byte [rcx], '+'   
        je .positive        
    .do_positiv:
	sub rsp, 8
        call parse_uint
	add rsp, 8
        test rdx, rdx          ; Проверяем, было ли прочитано число
        jz .end              
        cmp r8, 1    ; Проверяем, есть ли знак
        jnz .sign_add    
        jmp .end       
    .negative:
        mov dword r8d, 1  
        inc rcx                
        jmp .do_positiv
    .positive:
        inc rcx               
        jmp .do_positiv
    .sign_add:
        neg rax       
        jmp .end
    .end:
        xor rax, rax 
        ret

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rax, rax
    xor rdx, rdx
    xor rcx, rcx   
    .loop_string:
        mov bl, byte [rdi + rcx]
        cmp bl, 0
        je .end
        inc rcx
        cmp rcx, rsi
        jae .end_null
        mov [rdi + rcx - 1], bl
        jmp .loop_string
    .end:
        mov rax, rax
        ret
    .end_null:
        mov rax, rcx
        ret
