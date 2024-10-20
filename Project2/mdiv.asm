section .text
    global mdiv

mdiv:
    ; Arguments:
    ; rdi - pointer to the array (dividend)
    ; rsi - size of the array (number of elements in the array)
    ; rdx - divisor

    ; --------------------------------------------
    ; SECTION 1: normalize the dividend
    ; --------------------------------------------

    xor r10, r10                            ; set r10 to 0 if the dividend is positive
    cmp qword [rdi + rsi*8 - 8], 0          ; check if the last element of the array is negative
    jns .dividend_positive                   ; jump if the dividend is positive

    ; NEGATIVE DIVIDEND:
    inc r10                                 ; set r10 to 1 if the dividend is negative
    xor r9, r9                              ; set r9 to 0 (array index)
    stc                                     ; set CF to 1 at the start of the loop
    mov rcx, rsi                            ; set the counter to the length of the array

.negation_dividend_loop:                      ; iterate over the elements of the array

    not qword [rdi + r9*8]                  ; negate the bits of the element in the array
    adc qword [rdi + r9*8], 0               ; add 1 to the element in the array if CF is 1
    inc r9                                  ; move to the next element
    loop .negation_dividend_loop

.dividend_positive:

    ; --------------------------------------------
    ; SECTION 2: normalize the divisor
    ; --------------------------------------------

    xor r11, r11                            ; set r11 to 0 if the divisor is positive
    test rdx, rdx                           ; check if the divisor is negative
    jns .divisor_positive                    ; jump if the divisor is positive

    ; NEGATIVE DIVISOR:
    inc r11                                 ; set r11 to 1 if the divisor is negative
    neg rdx                                 ; negate the divisor

.divisor_positive:

    ; --------------------------------------------
    ; SECTION 3: division
    ; --------------------------------------------

    mov r8, rdx                             ; store the divisor in r8
    xor rdx, rdx                            ; set rdx to 0 (rdx will hold the remainder from the previous division)
    mov rcx, rsi                            ; set the counter to the size of the array

.division_loop:                             ; divide the elements of the array

    mov rax, qword [rdi + rcx*8 - 8]        ; set rax to the lower 64 bits of the dividend
    div r8                                  ; divide (RDX:RAX / r8) -> (RAX r RDX)
    mov qword [rdi + rcx*8 - 8], rax        ; store the division result in the array
    loop .division_loop                     ; continue the loop until rcx == 0

    ; --------------------------------------------
    ; SECTION 4: normalize the remainder
    ; --------------------------------------------

    mov rax, rdx                            ; set rax to the remainder from the division
    test r10, r10                           ; check if r10 is zero (the dividend was positive)
    jz .remainder_positive
    neg rax                                 ; if the dividend was negative, negate the remainder

.remainder_positive:

    ; --------------------------------------------
    ; SECTION 5: normalize the result
    ; --------------------------------------------

    cmp r10, r11                            ; check if the dividend and divisor have the same sign
    jz .result_positive                      ; jump if the dividend and divisor have the same sign

    ; NEGATION OF RESULT:
    xor r9, r9                              ; set r9 to 0
    stc                                     ; set CF to 1 at the start of the loop
    mov rcx, rsi                            ; set the counter to the length of the array

.negation_result_loop:
    not qword [rdi + r9*8]                  ; negate the bits of the element in the array
    adc qword [rdi + r9*8], 0               ; add 1 to the element in the array if CF is 1
    inc r9                                  ; move to the next element
    loop .negation_result_loop

    ret                                     ; end the function

.result_positive:

    cmp qword [rdi + rsi*8 - 8], 0          ; check if the result is negative
    js .overflow                             ; if the result is negative, check for overflow
    ret
.overflow:

    div rcx                                 ; divide by 0 to trigger SIGFPE (overflow)
