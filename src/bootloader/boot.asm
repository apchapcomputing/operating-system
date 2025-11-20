org 0x7c00
bits 16


%define ENDL 0x0d, 0x0a


; FAT12 header
jmp short start
nop


bdb_oem_id:                 db 'NBOS    ' ; OEM ID (8 bytes)
bdb_bytes_per_sector:       dw 512 ; Bytes per sector
bdb_sectors_per_cluster:    db 1 ; Sectors per cluster
bdb_reserved_sectors:       dw 1 ; Reserved sectors
bdb_fat_count:              dw 2
bdb_dir_entries_count:      dw 0e0h
bdb_total_sectors:          dw 2880
bdb_media_descriptor_type:  db 0f0h
bdb_sector_per_fat:         dw 9
bdb_sectors_per_track:      dw 18
bdb_heads:                  dw 2
bdb_hidden_sectors:         dd 0
bdb_large_sector_count:     dd 0

; extended boot record
ebr_drive_number:           db 0
                            db 0
ebr_signature:              db 29h
ebr_volume_id:              db 12h, 34h, 56h, 78h
ebr_volume_label:           db 'ASHLYN OS   '
ebr_system_id:              db 'FAT12   '


start:
    jmp main



; prints a string to the screen
; - ds:si points to the string
puts:
    push si
    push ax


.loop:
    lodsb                   ; loads next character into al
    or al, al               ; verify if next character is null
    jz .done

    mov ah, 0x0e            ; call bios interrupt
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
    mov sp, 0x7c00          ; stack grows downward from where we loaded into memory (org)

    ; save drive number
    mov [ebr_drive_number], dl
    
    ; read something from disk
    mov ax, 1               ; LBA = 1, second sector from disk
    mov cl, 1               ; 1 sector to read
    mov dl, [ebr_drive_number]
    mov bx, 0x7E00          ; copy from disk to 0x7E00
    call disk_read

    ; print message
    mov si, msg_hello
    call puts

    cli
    hlt


floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot


wait_key_and_reboot:
    mov ah, 0
    int 16h
    jmp 0FFFFh:0


.halt:
    cli
    hlt


; Converts LBA address to CHS address
; Parameters:
;   - ax: LBA address
; Returns:
;   - cx [bits 0-5]: sector number
;   - cx [bits 6-15]: cylinder
;   - dh: head
lba_to_chs:
    push ax
    push dx

    xor dx, dx                          ; dx = 0
    div word [bdb_sectors_per_track]    ; ax = LBA / SectorsPerTrack
                                        ; dx = LBA % SectorsPerTrack

    inc dx                              ; dx = (LBA % SectorsPerTrack) + 1 = sector
    mov cx, dx                          ; cx = sector

    xor dx, dx                          ; dx = 0
    div word [bdb_heads]                ; ax = (LBA / SectorsPerTrack) / Heads = cylinder
                                        ; dx = (LBA / SectorsPerTrack) % Heads = head
    mov dh, dl                          ; dh = head
    mov ch, al                          ; ch = cylinder (lower 8 bits)
    shl ah, 6
    or cl, ah                           ; put upper 2 bits of cylinder in cl

    pop ax
    mov dl, al                          ; restore dl
    pop ax
    ret


; Reads sectors from a disk
; Parameters:
;   - ax: LBA address
;   - cl: number of sectors to read (up to 128)
;   - dl: drive number
;   - es:bx: memory address where to store read data
disk_read:
    push ax                 ; save registers we'll modify
    push bx
    push cx
    push dx
    push di
    
    push cx                 ; temporarily save CL (number of sectors)
    call lba_to_chs         ; compute CHS
    pop ax                  ; AL = number of sectors to read
    
    mov ah, 02h
    mov di, 3               ; retry count


.retry:
    pusha                   ; save all registers, we don't know what bios modifies
    stc                     ; set carry flag, some BIOS'es don't set it
    int 13h                 ; carry flag cleared = success
    jnc .done
    
    ; read failed
    popa
    call disk_reset

    dec di
    test di, di
    jnz .retry


.fail:
    jmp floppy_error


.done:
    popa

    pop di                  ; restore registers in correct order
    pop dx
    pop cx
    pop bx
    pop ax     
    ret


; Resets disk controller
disk_reset:
    pusha
    mov ah, 0
    stc
    int 13h
    jc floppy_error
    popa
    ret


msg_hello:                  db 'Hello, world!', ENDL, 0
msg_read_failed:            db 'Read from disk failed!', ENDL, 0


times 510-($-$$) db 0
dw 0aa55h 