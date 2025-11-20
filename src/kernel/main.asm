org 0x7c00
bits 16


%define ENDL 0x0d, 0x0a


start:
    jmp main


; prints a string to the screen
; - ds:si points to the string

puts:
    push si
    push ax


.loop:
    lodsb ; loads next character into al
    or al, al ; verify if next character is null
    jz .done

    mov ah, 0x0e ; call bios interrupt
    int 0x10

    jmp .loop

.done:
    pop ax
    pop si
    ret


main:

    ; setup data segments
    mov ax, 0
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7c00 ; stack grows downward from where we loaded into memory (org)

    ; print message
    mov si, msg_hello
    call puts

    hlt


.halt:
    jmp .halt


msg_hello: db 'Hello, world!', ENDL, 0


times 510-($-$$) db 0
dw 0aa55h 