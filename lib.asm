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
    mov rsi, rdi        
    mov byte [rsp], al 
    mov rdx, 1
    mov rax, 1 ; write
    mov rdi, 1   ; stdout 
    syscall

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
    xor rax, rax
    sub rsp, 21 
    mov rax, rdi 
    mov rcx, 0 ; счётчик
    .loop:
        xor rdx, rdx
        mov rbx, 10
        div rbx
        sub dl, '0' ; Переводим остаток в ASCII
        mov [rsp + rcx], dl
        inc rcx
        cmp rax, 0
        je .loop
    .outRes:
        mov rax, 1
        mov rdi, 1
        mov rsi, rbx 
        mov rdx, rcx 
        syscall
        add rsp, 20
    ret

 
; Выводит знаковое 8-байтовое число в десятичном формате 
print_int:
    xor rax, rax
    cmp rdi, 0           ; Сравниваем с нулем
    je .zero_case         
    mov rax, rdi         ; Сохраняем число в rax
    cmp rax, 0 
    jge .possitiv 
    neg rax
    mov byte [rsp], '-'
    inc rsp
    .possitiv:
        call print_uint
        dec rsp
        ret
    .zero_case:
        mov byte [rsp], '0'  ; Выводим 0
        mov rax, 1
        mov rdi, 1
        mov rsi, rsp
        mov rdx, 1
        syscall
        sub rsp, 1           ; Увеличиваем указатель стека
        ret

; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    xor rax, rax
    call string_length 
    mov rdx, rax ; длина первой строки
    mov rax, rsi ;
    call string_length 
    mov rcx, rax
    cmp rdx, rcx
    je .equal_loop
    jmp .not_equal 
    .equal_loop:
        mov al, byte [rdi]      ; Загружаем байт из первой строки
        mov bl, byte [rsi]      ; Загружаем байт из второй строки
        cmp al, bl
        jne .not_equal 
        cmp al, 0         
        je .equal            
        inc rdi                 
        inc rsi                 
        jmp .equal_loop
    .not_equal:
        xor rax, rax 
        ret
    .equal:            
        mov rax, 1
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    mov rax, 1     
    sub rsp, 8               ; Выравнивание стека
    mov rdi, 0               ; stdin (0)
    lea rsi, [rsp + 8]       ; 1 байт в стеке
    mov rdx, 1
    syscall
    cmp rax, 0              ; конец потока
    jne .not_end 
    xor rax, rax            
    add rsp, 8             
    ret
    .not_end:
        mov al, byte [rsp + 8]  
        add rsp, 8              
        ret

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор

read_word:
    xor rax, rax
    xor rcx, rcx  
    .loop_spaces:
        call read_char      
        cmp rax, 0           
        je .end
        cmp al, 0x20
        je .leave_char
        cmp al, 0x9   
        je .leave_char
        cmp al, 0xA
        je .leave_char
        mov [rdi + rax], al   
        inc rax               
        inc rcx                
        cmp rcx, rsi          ; проверяем, не превышен ли размер буфера
        jge .end 
        jmp .loop_spaces
    .leave_char:
        inc rax
        jmp .loop_spaces
    .end:
        xor rax, rax 
        ret
 

; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax
    xor rdx, rdx
    .loop_digit:
        mov al, [rdi + rdx] ; байт из строки
        test al, al          ; конца строки
        jz .end               
        sub al, '0'           ; преобразование ASCII в число
        mov  rbx, rax        
        ; Проверяем на переполнение 
        shl  rax, 1           ; Умножаем на 2 
        add  rax, rax         ; rax *= 10
        add  rax, rbx         ; rax += новое число
        mov  rdx, rax         
        inc  rdx             
        inc  rdi             
        jmp .loop_digit    
    .end:
        xor rax, rdx
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
        call parse_uint
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
