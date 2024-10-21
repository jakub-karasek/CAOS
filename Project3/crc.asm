section .bss
    buffer resb 65540                          ; buffer of size 65540 bytes
    ; size is 65540 to fit the maximum fragment size along with the offset

section .text
global _start

_start:
    xor r13, r13                                ; zero r13, where the result will be stored
    xor r15, r15                                ; zero r15, where the file status will be stored

    mov rax, [rsp]                              ; set rax to the number of arguments
    cmp rax, 3                                  ; check if three arguments were provided
    jne .error                                  ; return an error if the number of arguments is incorrect

;READING THE POLYNOMIAL

    mov rcx, 64
    mov rsi, QWORD [rsp+24]                     ; set rsi to the address of the first character of the polynomial
    xor r9, r9                                  ; zero r9, where the polynomial will be stored

    mov al, [rsi]                               ; set al to the ASCII code of the first character of the polynomial
    test al, al                                 ; check if the polynomial is empty
    jz .error                                   ; return an error if the polynomial is empty

    .loop_string:
    lodsb                                       ; load a byte of the polynomial into al

    test al, al                                 ; check if al is zero
    je .end                                     ; jump if it's the end of the string

    sub al, '0'                                 ; convert al from ASCII to numerical value
    cmp al, 1                                   ; check if there are characters other than 0 and 1
    ja .error                                   ; return an error if there are invalid characters

    add r9b, al                                 ; add one character to r9

    cmp rcx, 1                                  ; check if the polynomial length is 64
    je .max_polynomial                          ; end the loop early if the polynomial is 64 bits long

    shl r9, 1                                   ; shift r9 to make room for the next character

    loop .loop_string

    .end:
    dec cl

    movzx r14, cl                               ; set r14 to the length of the polynomial suffix
    shl r9, cl                                  ; shift r9 so the polynomial becomes the prefix

    inc r14
    .max_polynomial:
    dec r14                                     ; adjust the suffix size for a polynomial of length 64

;READING FRAGMENTS INTO THE BUFFER ONE BY ONE

    ; open the file using sys_open
    mov rdi, QWORD [rsp+16]                     ; pointer to the file name
    mov rsi, 0                                  ; read-only mode
    mov rax, 2                                  ; system call number for sys_open
    syscall                                     ; call sys_open

    test rax, rax                               ; check if opening succeeded
    js .error                                   ; if not, return an error

    mov rdi, rax                                ; set rdi to the file descriptor
    mov r15, 1

    ; check the file pointer position
    mov rax, 8                                  ; set rax to the system call number for sys_lseek
    xor rsi, rsi                                ; set offset to 0 bytes
    mov rdx, 1                                  ; set rdx to the current position
    syscall                                     ; call sys_lseek

    test rax, rax                               ; check if syscall succeeded
    js .error                                   ; if not, return an error

    mov r10, rax                                ; set r10 to the current position

    .start:

    ; read the fragment size
    mov rsi, buffer                             ; set rsi to the buffer pointer
    mov rdx, 2                                  ; set rdx to 2 to read the length of the fragment
    mov rax, 0                                  ; set rax to the system call number for sys_read
    syscall                                     ; call sys_read

    test rax, rax                               ; check if syscall succeeded
    js .error                                   ; if not, return an error

    movzx r8, word [buffer]                     ; set r8 to the number of bytes

    ; read the rest of the fragment
    mov rax, 0                                  ; set rax to the system call number for sys_read
    mov rsi, buffer                             ; set rsi to the buffer pointer
    mov rdx, r8                                 ; set rdx to the fragment length
    add rdx, 4                                  ; increase rdx by the size of the offset
    syscall                                     ; call sys_read

    cmp rax, 0                                  ; check if syscall succeeded
    jle .error                                  ; if not, return an error

    ; check the file position after the offset
    mov rax, 8                                  ; set rax to the system call number for sys_lseek
    movsxd rsi, dword [buffer + r8]             ; set rsi to the offset
    mov rdx, 1                                  ; set rdx to the current position
    syscall                                     ; call sys_lseek

    test rax, rax                               ; check if syscall succeeded
    js .error                                   ; if not, return an error

    mov r11, rax                                ; set r11 to the position after the offset

    test r8, r8                                 ; check if the fragment is empty
    jz .empty_fragment                          ; jump if the fragment is empty

;CALCULATING CRC

    xor r12, r12                                ; zero r12
    clc                                         ; reset CF

    .crc_loop:

    mov al, [buffer + r12]                      ; set al to a byte from the buffer
    mov rcx, 8                                  ; set the loop counter to 8

    .crc_inner_loop:

    rcl al, 1                                   ; shift CF into al
    rcl r13, 1                                  ; shift CF into r13 and r13's bit into CF
    jnc .skip                                   ; jump if the first bit was zero
    xor r13, r9                                 ; xor the result with the polynomial
    .skip:

    loop .crc_inner_loop

    inc r12
    cmp r12, r8                                 ; check if the loop should end

    jne .crc_loop

;CHECK IF THIS IS THE LAST FRAGMENT

    .empty_fragment:

    cmp r10, r11                                ; check if the offset points to the beginning of the fragment
    mov r10, r11
    jne .start                                  ; jump to the beginning if it's not the last fragment

;NORMALIZE THE RESULT

    mov rcx, 64                                 ; set the loop counter to 64

    .reset_loop:

    clc                                         ; reset CF
    rcl r13, 1                                  ; shift the first bit of r13 into CF
    jnc .skip_xor                               ; jump if the first bit was zero
    xor r13, r9                                 ; xor the result and the polynomial
    .skip_xor:

    loop .reset_loop

;OUTPUT THE RESULT

    ; set r10 to the length of the result
    mov r10, 64
    sub r10, r14
    dec r10

    xor rcx, rcx                                ; zero rcx

    .result_to_buffer:

    xor al, al                                  ; reset al
    rcl r13, 1                                  ; shift the result character into CF
    adc al, '0'                                 ; add CF to al and convert to ASCII
    mov BYTE [buffer + rcx], al                 ; add the ASCII code of the result character to the buffer

    inc cl
    cmp rcx, r10                                ; check if the loop should end
    jne .result_to_buffer

    mov BYTE [buffer + r10], 10                 ; add a newline to the buffer

    ; output the result to the terminal using sys_write
    mov rax, 1                                  ; set rax to the system call number for sys_write
    mov rdi, 1                                  ; set rdi to the standard output (terminal)
    mov rsi, buffer                             ; set rsi to the length of the result
    mov rdx, r10
    add rdx, 1
    syscall                                     ; call sys_write

    test rax, rax                               ; check if syscall succeeded
    js .error                                   ; if not, return an error

;END THE PROGRAM

    xor r9, r9                                  ; set r9 to zero
    jmp .no_error

    .error:
    mov r9, 1                                   ; in case of error, set r9 to 1

    .no_error:

    cmp r15, 1                                  ; check if the file was opened
    jne .file_not_opened

    ; close the file
    mov rdi, rax                                ; set rdi to the file descriptor
    mov rax, 3                                  ; set rax to the system call number for sys_close
    syscall                                     ; call sys_close

    .file_not_opened:

    ; end the program
    mov rdi, r9                                 ; set r9 as the exit code
    mov rax, 60                                 ; set rax to the system call number for sys_exit
    syscall                                     ; call sys_exit
