section .text
    global mdiv

mdiv:
    ; Argumenty:
    ; rdi - wskaźnik na tablicę (dzielna)
    ; rsi - rozmiar tablicy (liczba elementów w tablicy)
    ; rdx - dzielnik

    ; --------------------------------------------
    ; SEKCJA 1: normalizacja dzielnej
    ; --------------------------------------------

    xor r10, r10                            ; ustawiam r10 na 0, jeśli dzielna jest dodatnia
    cmp qword [rdi + rsi*8 - 8], 0          ; sprawdzam, czy ostatni element tablicy jest ujemny
    jns .dzielna_dodatnia                    ; skacz, jeśli dzielna jest dodatnia

    ; DZIELNA UJEMNA:
    inc r10                                 ; ustawiam r10 na 1, jeśli dzielna jest ujemna
    xor r9, r9                              ; ustawiam r9 na 0 (indeks tablicy)
    stc                                     ; ustawiam CF na 1 na początek pętli
    mov rcx, rsi                            ; ustawiam licznik na długość tablicy

.negacja_dzielnej_loop:                      ; iteruję po elementach tablicy

    not qword [rdi + r9*8]                  ; neguję bity elementu w tablicy
    adc qword [rdi + r9*8], 0               ; dodaję 1 do elementu tablicy, jeśli CF jest równy 1
    inc r9                                  ; przechodzę do następnego elementu
    loop .negacja_dzielnej_loop

.dzielna_dodatnia:

    ; --------------------------------------------
    ; SEKCJA 2: normalizacja dzielnika
    ; --------------------------------------------

    xor r11, r11                            ; ustawiam r11 na 0, jeśli dzielnik jest dodatni
    test rdx, rdx                           ; sprawdzam, czy dzielnik jest ujemny
    jns .dzielnik_dodatni                    ; skacz, jeśli dzielnik jest dodatni

    ; DZIELNIK UJEMNY:
    inc r11                                 ; ustawiam r11 na 1, jeśli dzielnik jest ujemny
    neg rdx                                 ; neguję dzielnik

.dzielnik_dodatni:

    ; --------------------------------------------
    ; SEKCJA 3: dzielenie
    ; --------------------------------------------

    mov r8, rdx                             ; zapamiętuję dzielnik w r8
    xor rdx, rdx                            ; ustawiam rdx na 0 (rdx będzie trzymało resztę z poprzedniego dzielenia)
    mov rcx, rsi                            ; ustawiam licznik na rozmiar tablicy

.dzielenie_loop:                             ; dzielę elementy tablicy

    mov rax, qword [rdi + rcx*8 - 8]        ; ustawiam rax na dolne 64b dzielnej
    div r8                                  ; dzielę (RDX:RAX / r8) -> (RAX r RDX)
    mov qword [rdi + rcx*8 - 8], rax        ; wynik dzielenia zapisuję w tablicy
    loop .dzielenie_loop                     ; kontynuuję pętlę, aż rcx == 0

    ; --------------------------------------------
    ; SEKCJA 4: normalizacja reszty
    ; --------------------------------------------

    mov rax, rdx                            ; ustawiam rax na resztę z dzielenia
    test r10, r10                           ; sprawdzam, czy r10 jest zerem (dzielna była dodatnia)
    jz .reszta_dodatnia
    neg rax                                 ; jeśli dzielna była ujemna, neguję resztę z dzielenia

.reszta_dodatnia:

    ; --------------------------------------------
    ; SEKCJA 5: normalizacja wyniku
    ; --------------------------------------------

    cmp r10, r11                            ; sprawdzam, czy dzielna i dzielnik mają ten sam znak
    jz .wynik_dodatni                        ; skacz, jeśli dzielna i dzielnik mają ten sam znak

    ; NEGACJA WYNIKU:
    xor r9, r9                              ; ustawiam r9 na 0
    stc                                     ; ustawiam CF na 1 na początek pętli
    mov rcx, rsi                            ; ustawiam licznik na długość tablicy

.negacja_wyniku_loop:
    not qword [rdi + r9*8]                  ; neguję bity elementu tablicy
    adc qword [rdi + r9*8], 0               ; dodaję 1 do elementu tablicy, jeśli CF jest równy 1
    inc r9                                  ; przechodzę do następnego elementu
    loop .negacja_wyniku_loop

    ret                                     ; kończę funkcję

.wynik_dodatni:

    cmp qword [rdi + rsi*8 - 8], 0          ; sprawdzam, czy wynik jest ujemny
    js .overflow                             ; jeśli wynik jest ujemny, sprawdzam, czy wystąpił overflow
    ret
.overflow:

    div rcx                                 ; dzielę przez 0, aby wywołać SIGFPE (overflow)

