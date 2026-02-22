; -----------------------------------------------------------------------------
;
; Project:      CoreaLoader
; Name:         First Stage Boot Sector (MBR)
; File:         bootloader.asm
; Author:       @lorick_la_brique
; Date:         22 February 2026 - Revision 2
; Description:  Loads the rest of the OS from disk. Optimized to use the 
;               boot drive ID provided by the BIOS and load more sectors.
;
; -----------------------------------------------------------------------------

[bits 16]
org 0x7C00                      ; MBR starts at 0x7C00

start:
    jmp 0:init_segments          ; Far jump to fix CS to 0

init_segments:
    cli                         ; Disable interrupts during setup
    mov [BOOT_DRIVE], dl        ; Save boot drive ID (passed by BIOS in DL)
    
    xor ax, ax                  ; AX = 0
    mov ds, ax                  ; Set data segment
    mov es, ax                  ; Set extra segment
    mov ss, ax                  ; Set stack segment
    mov sp, 0x7C00              ; Stack grows downwards from 0x7C00
    sti                         ; Re-enable interrupts for BIOS calls

    ; Print greeting
    mov si, msg_boot
    call print_string_16

    ; Load Stage 2 + Kernel
    ; We load from Sector 2 (where stage 2 starts) to 0x8000
    mov ax, 0x0800              ; ES:BX = 0x0000:0x8000 (via AX)
    mov es, ax
    xor bx, bx
    
    mov ah, 0x02                ; BIOS read sectors function
    mov al, 64                  ; Number of sectors to read (32KB - enough for now)
    mov ch, 0                   ; Cylinder 0
    mov dh, 0                   ; Head 0
    mov cl, 2                   ; Start from Sector 2
    mov dl, [BOOT_DRIVE]        ; Use the saved boot drive
    int 0x13                    ; Call BIOS
    jc disk_error               ; Jump if carry flag (error)

    ; Jump to Stage 2
    mov si, msg_jump
    call print_string_16
    jmp 0:0x8000                ; Transfer control to second_stage.asm

disk_error:
    mov si, msg_error
    call print_string_16
    hlt
    jmp $

; --- Helper: Print String ---
print_string_16:
    lodsb
    or al, al
    jz .done
    mov ah, 0x0E
    int 0x10
    jmp print_string_16
.done:
    ret

; --- Data ---
BOOT_DRIVE db 0
msg_boot   db "Nexora MBR Loading...", 0x0D, 0x0A, 0
msg_jump   db "Jumping to Stage 2...", 0x0D, 0x0A, 0
msg_error  db "Disk Error!", 0

times 510-($-$$) db 0           ; Padding to 510 bytes
dw 0xAA55                       ; Boot signature