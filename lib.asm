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
    .equal_loop:
        mov r11b, byte [rdi] ; Загружаем байт из первой строки     
        cmp r11b, byte [rsi] ; сравниваем байт из 1ой строки и байт из 2ой     
        jne .not_equal 
        cmp r11b, 0 ; проверяем на нуль-терминант
        je .equal            
        inc rdi                 
        inc rsi                 
        jmp .equal_loop
    .equal:            
        mov rax, 1
        ret
    .not_equal:
        xor rax, rax
        ret

; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    push 0                 ; Резервируем место на стеке для символа
    mov rdx, 1             ; Устанавливаем длину чтения в 1 байт
    mov rsi, rsp           ; Указатель на зарезервированное место в стеке
    mov rax, 0             ; Системный вызов для чтения
    mov rdi, 0             ; стандартный ввод (stdin)
    syscall                ; Выполняем системный вызов
    pop rax                ; Извлекаем символ из стека в rax
    ret                    ; Возвращаемся из функции

; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push rdi                 ; Сохраняем начальный адрес буфера
    push r12                 ; Сохраняем регистр r12 (callee-saved)
    mov r12, rdi             ; r12: текущий адрес буфера
    push r13                 ; Сохраняем регистр r13 (callee-saved)
    mov r13, rsi             ; r13: текущий размер буфера
    test r13, r13            ; Проверяем, пустой ли буфер
    jz .buffer_too_small     ; Если да, буфер слишком мал
.skip_whitespace:
    call read_char           ; Считываем символ
    cmp rax, 0x20            ; Пробел?
    je .skip_whitespace      ; Пропускаем, если пробел
    cmp rax, 0x9             ; Табуляция?
    je .skip_whitespace      ; Пропускаем, если табуляция
    cmp rax, 0xA             ; Перевод строки?
    je .skip_whitespace      ; Пропускаем, если перевод строки
.read_word_loop:
    cmp rax, 0x0             ; Нуль-терминатор - конец чтения
    je .complete_read
    cmp rax, 0x20            ; Пробел - конец чтения слова
    je .complete_read
    cmp rax, 0x9             ; Табуляция - конец чтения слова
    je .complete_read
    cmp rax, 0xA             ; Перевод строки - конец чтения слова
    je .complete_read
    dec r13                  ; Уменьшаем оставшийся размер буфера
    cmp r13, 0               ; Проверяем, не переполнен ли буфер
    jbe .buffer_too_small    ; Если буфер переполнен, ошибка
    mov byte [r12], al       ; Записываем символ в буфер
    inc r12                  ; Переходим к следующей позиции в буфере
    call read_char           ; Считываем следующий символ
    jmp .read_word_loop      ; Продолжаем цикл чтения
.complete_read:
    mov byte [r12], 0x0      ; Добавляем нуль-терминатор в конце слова
    pop r13
    pop r12
    mov rdi, [rsp]           ; Загружаем rdi из стека
    call string_length       ; Определяем длину считанного слова
    mov rdx, rax             ; Длина слова сохраняется в rdx
    pop rax
    ret                      ; Возвращаем результат
.buffer_too_small:
    pop r13
    pop r12
    pop rdi
    xor rax, rax             ; Ошибка: возвращаем 0
    ret


; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax  
    xor rdx, rdx 
    xor r10, r10 ; для хранения числа
    xor r9, r9 ; Счетчик символов
    .loop_digit:
        mov r10b, byte [rdi + r9] ; байт из строки  
        sub r10b, '0' ; преобразование ASCII в число
        cmp r10b, 0                
        jl .end                    
        cmp r10b, 9            
        ja .end ; Если больше 9, выходим
        ; Умножаем текущее значение на 10
        ; rax * 10 = (rax << 1) + (rax << 3)
        push rdx
        mov rdx, rax ; Сохраняем текущее значение rax
        shl rax, 3 ; Умножаем на 8 
        shl rdx, 1 ; Умножаем на 2 
        add rax, rdx ; складываем
        pop rdx

        add rax, r10  ; добавляем текущую цифру               
        inc r9 ; Увеличиваем счетчик
        jmp .loop_digit             
    .end:
        mov rdx, r9  
        ret


; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был) 
; rdx = 0 если число прочитать не удалось
parse_int:         
    xor rdx, rdx ;       
    cmp byte [rdi], '-'   
    je .negative 
    cmp byte [rdi], 0    
    je .endnull     
    .positive:
        sub rsp, 8 ; 16
        call parse_uint
        add rsp, 8
        jmp .end             
    .negative:
        inc rdi ; переходим на следующий символ
        sub rsp, 8 ; 16
        call parse_uint
        add rsp, 8
        neg rax
        inc rdx ; увеличиваем длину на 1
    .end: 
        ret
    .endnull:
        xor rax, rax
        mov rdx, 1
        ret  

; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    ; Если буфер сразу нулевой то просто идём в состояние overflow 
    test rdx, rdx
    jz .overflow
    ; инициализировали длинну
    xor rax, rax
 .cycle:
    ; скопировали очередной символ
    mov r10b, byte [rdi]
    mov byte [rsi], r10b
    inc rax
    inc rdi
    inc rsi
    ; Если пришли в нуль-терминатор переходи в состояние completed
    cmp r10b, 0
    je .completed
    ; Если места в буфере больше нет то в состояние overflow
    cmp rdx, rax
    je .overflow

    jmp .cycle

 .overflow:
    xor rax, rax
    ret

 .completed:
    ret
