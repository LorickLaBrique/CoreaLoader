; ==============================================================================
;
; Name:         First Stage Boot Sector (MBR/VBR)
; File:         bootloader.asm
; Author:       @lorick_la_brique
; Date:         02 November 2025 - Revision 1
; Description:  16-bit code loaded at 0x7C00. Initializes segments, prints a 
;               message, loads the Second Stage (starting at sector 2) into 
;               memory address 0x8000, and jumps to it.
;
; ==============================================================================

[bits 16]
org 0x7C00                      ; Tells NASM that the code will be loaded at 0x7C00

start:
    cli                         ; Disable interrupts (important before segment manipulation)
    xor ax, ax
    mov ds, ax                  ; Set data segment (DS) to 0
    mov es, ax                  ; Set extra segment (ES) to 0
    mov ss, ax                  ; Set stack segment (SS) to 0
    mov sp, 0x7C00              ; Set stack pointer (SP) right below the code

; Print MBR message to the screen using BIOS INT 0x10
    mov si, msg                 ; SI points to the start of the message string
.print_char:
    lodsb                       ; Load AL with byte pointed to by SI, and increment SI
    cmp al, 0
    je .done_msg                ; If AL is null terminator (0), exit loop
    mov ah, 0x0E                ; BIOS Teletype function
    int 0x10                    ; Call BIOS to print the character
    jmp .print_char
.done_msg:

; Load second stage (Stage 2) into memory using BIOS INT 0x13
; 
    mov bx, 0x8000              ; Destination buffer address (ES:BX = 0x0000:0x8000)
    mov ah, 0x02                ; Function: Read Sector(s) from Drive
    mov al, 40                  ; Number of sectors to read (40 sectors = 20 KB)
    mov ch, 0                   ; Cylinder (Track) 0
    mov cl, 2                   ; Starting Sector (Sector 1 is the MBR, so start at Sector 2)
    mov dh, 0                   ; Head 0
    mov dl, 0x80                ; Drive Number: 0x00=Floppy A:, 0x80=First Hard Disk
    int 0x13
    jc disk_error               ; Jump if carry flag (CF) is set (read error)

    ; Jump to the loaded second stage code
    jmp 0x0000:0x8000           ; Far jump to 0x8000 (CS:IP)

disk_error:
    ; Simple error handling: halt and loop forever
    hlt
    jmp disk_error

msg db "Booting NexoraOS !",0x0D,0x0A,0
times 510-($-$$) db 0           ; Pad the boot sector up to byte 510
dw 0xAA55                       ; Boot signature at bytes 510 and 511