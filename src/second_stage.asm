; -----------------------------------------------------------------------------
;
; Project:      CoreaLoader
; Name:         Three-Stage Bootloader Transition
; File:         second_stage.asm
; Author:       @lorick_la_brique
; Date:         02 November 2025 - Revision 1
; Description:  This second-stage bootloader module handles the transition from 
;               16-bit Real Mode to 32-bit Protected Mode, and finally to 
;               64-bit Long Mode (x86_64). It includes crucial steps like A20 
;               gate activation, GDT loading, and page table setup for Long Mode.
;
; -----------------------------------------------------------------------------

[BITS 16]
ORG 0x8000                          ; Loaded by bootloader.asm at this address

start:
    ; 1. System Initialization
    cli                             ; Disable interrupts
    xor ax, ax                      ; AX = 0
    mov ds, ax                      ; DS = 0
    mov es, ax                      ; ES = 0
    mov ss, ax                      ; SS = 0
    mov sp, 0x7C00                  ; Set stack below boot sector

    ; 2. Print 16-bit start message
    mov si, msg16                   ; Load message address
.print16:
    lodsb                           ; Load byte into AL
    or al, al                       ; Check for null terminator
    jz .after16                     ; If 0, exit loop
    mov ah, 0x0E                    ; BIOS teletype
    int 0x10                        ; Print character
    jmp .print16
.after16:

    ; 3. Get Memory Map (E820)
    mov di, 0x9004                  ; Map entries start at 0x9004
    xor ebx, ebx                    ; EBX must be 0 to start
    xor bp, bp                      ; Entry counter
    mov edx, 0x534D4150             ; 'SMAP' signature
.mmap_loop:
    mov eax, 0xE820                 ; Function code
    mov ecx, 24                     ; Entry size
    int 0x15                        ; Call BIOS
    jc .mmap_done                   ; If carry, we are done
    cmp eax, 0x534D4150             ; Verify signature
    jne .mmap_done
    add di, 24                      ; Next entry slot
    inc bp                          ; Increment count
    test ebx, ebx                   ; If ebx=0, end of list
    jnz .mmap_loop
.mmap_done:
    mov [0x9000], bp                ; Store entry count at 0x9000

    ; 4. Enable A20 Gate
    in al, 0x92                     ; Read System Control Port A
    or al, 2                        ; Set bit 1 (A20 enable)
    out 0x92, al                    ; Write back

    ; 5. Load GDT
    lgdt [gdt_descriptor]           ; Load GDT Pointer

    ; 6. Transition to Protected Mode
    mov eax, cr0                    ; Read CR0
    or eax, 1                       ; Set PE (Protection Enable) bit
    mov cr0, eax                    ; Write CR0

    ; 7. Far Jump to 32-bit (flushes pipeline)
    jmp 0x08:protected32_start      ; 0x08 is Code Segment in GDT

; ------------------------------
; Global Descriptor Table (GDT)
; ------------------------------
align 8
gdt_start:
    dq 0x0000000000000000           ; Null Descriptor
    dq 0x00CF9A000000FFFF           ; 0x08: 32-bit Code (Base 0, Limit 4GB, G=1)
    dq 0x00CF92000000FFFF           ; 0x10: 32-bit Data (Base 0, Limit 4GB, G=1)
    dq 0x00AF98000000FFFF           ; 0x18: 64-bit Code (L=1, D=0)
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; GDT Size - 1
    dd gdt_start                    ; GDT Base Address

; ------------------------------
; Protected 32-bit mode
; ------------------------------
[BITS 32]
protected32_start:
    mov ax, 0x10                    ; Load Data Segment selector
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x90000                ; Setup 32-bit stack
    mov fs, ax
    mov gs, ax

    ; 1. Setup Page Tables (PML4 -> PDPT -> PD -> PT)
    ; Clear 4 pages starting at 0x10000 (safe area)
    mov edi, 0x10000                ; Page tables base
    mov ecx, 4096                   ; 4 pages * 4096 / 4 bytes
    xor eax, eax
    rep stosd                       ; Zero out memory

    ; 2. Identity Map first 2MB
    mov edi, 0x10000                ; EDI = PML4
    lea eax, [edi + 0x1000]         ; EAX = PDPT address
    or eax, 3                       ; Present + R/W
    mov [edi], eax                  ; PML4[0] -> PDPT

    lea edi, [edi + 0x1000]         ; EDI = PDPT
    lea eax, [edi + 0x1000]         ; EAX = PD address
    or eax, 3                       ; Present + R/W
    mov [edi], eax                  ; PDPT[0] -> PD

    lea edi, [edi + 0x1000]         ; EDI = PD
    lea eax, [edi + 0x1000]         ; EAX = PT address
    or eax, 3                       ; Present + R/W
    mov [edi], eax                  ; PD[0] -> PT

    lea edi, [edi + 0x1000]         ; EDI = PT
    mov eax, 3                      ; EAX = Phys Addr 0 + Flags
    mov ecx, 512                    ; Map 512 entries (2MB)
.map_pt:
    mov [edi], eax                  ; Store entry
    add eax, 4096                   ; Next physical page
    add edi, 8                      ; Next entry (64-bit entries)
    loop .map_pt

    ; 3. Enable PAE and Long Mode
    mov eax, cr4                    ; Read CR4
    or eax, 1 << 5                  ; Set PAE bit
    mov cr4, eax                    ; Write CR4

    mov ecx, 0xC0000080             ; EFER MSR
    rdmsr                           ; Read MSR
    or eax, 1 << 8                  ; Set LME (Long Mode Enable)
    wrmsr                           ; Write MSR

    ; 4. Enable Paging
    mov eax, 0x10000                ; PML4 Address
    mov cr3, eax                    ; Load CR3
    mov eax, cr0                    ; Read CR0
    or eax, 1 << 31                 ; Set PG (Paging) bit
    mov cr0, eax                    ; Enable Paging

    ; 5. Jump to 64-bit Mode
    jmp 0x18:long_mode_start        ; Far jump to 64-bit segment

; ------------------------------
; Long mode (64-bit)
; ------------------------------
[BITS 64]
long_mode_start:
    mov ax, 0x10                    ; Reuse Data Segment
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov gs, ax
    mov rsp, 0x90000                ; Setup 64-bit stack

    ; Clear Screen
    mov rdi, 0xB8000                ; VGA buffer
    mov rcx, 2000                   ; 80*25 characters
    mov rax, 0x0F200F200F200F20     ; White spaces
    rep stosq                       ; Clear screen fast

    ; Print Messages
    mov rsi, msg64
    mov rdi, 0xB8000
    call print_string_64

    mov rsi, msg_safe
    mov rdi, 0xB80A0                ; Second line
    call print_string_64

.halt:
    hlt                             ; Halt CPU
    jmp .halt                       ; Loop in case of NMI

print_string_64:
.loop:
    lodsb                           ; Load char
    or al, al                       ; Check null
    jz .done
    mov ah, 0x0F                    ; Color
    mov [rdi], ax                   ; Write to VGA
    add rdi, 2                      ; Next VGA slot
    jmp .loop
.done:
    ret

; ------------------------------
; Messages
; ------------------------------
msg16   db "CoreaLoader Stage 2", 0x0D, 0x0A, 0
msg64   db "NexoraKernel: 64-bit Long Mode Active!", 0
msg_safe db "Memory Map (E820) stored at 0x9000. System Stable.", 0