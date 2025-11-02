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
ORG 0x8000 ; Typical load address by the first stage boot sector

start:
    ; 1. System Initialization in 16-bit Real Mode
    cli                     ; Disable interrupts (critical before mode transition)
    xor ax, ax              ; AX = 0
    mov ds, ax              ; Data Segment = 0
    mov es, ax              ; Extra Segment = 0
    mov ss, ax              ; Stack Segment = 0
    mov sp, 0x7C00          ; Set 16-bit Stack Pointer just below the boot sector (0x7C00)

    ; --- DEBUG 16-bit: print message using BIOS Int 0x10 ---
    mov si, msg16           ; Load address of 16-bit debug message
.print16:
    lodsb                   ; Load byte from [DS:SI] into AL, increment SI
    or al, al               ; Check if AL is null terminator (0)
    jz .after16             ; Jump if end of string
    mov ah, 0x0E            ; BIOS Teletype function (AH=0x0E, AL=char)
    int 0x10                ; Call BIOS interrupt to print character
    jmp .print16
.after16:

    ; 2. Enable A20 Gate (to access memory above 1MB) via port 0x92
    ; Read-Modify-Write sequence
    in al, 0x92             ; Read current state of port 0x92 (PS/2 Controller Auxiliary Port)
    or al, 00000010b        ; Set bit 1 (A20 enable)
    out 0x92, al            ; Write new value back

    ; Print A20 success message
    mov si, msg_a20
.print_a20:
    lodsb
    or al, al
    jz .after_a20
    mov ah, 0x0E
    int 0x10
    jmp .print_a20
.after_a20:

    ; 3. Load Global Descriptor Table (GDT)
    lgdt [gdt_descriptor]   ; Load the GDT register (GDTR)

    ; Print LGDT success message
    mov si, msg_lgdt
.print_lgdt:
    lodsb
    or al, al
    jz .after_lgdt
    mov ah, 0x0E
    int 0x10
    jmp .print_lgdt
.after_lgdt:

    ; 4. Set Protection Enable (PE) bit in Control Register 0 (CR0)
    ; Since we are in 16-bit mode, we must use the 32-bit opcodes directly (CR registers are 32-bit)
    db 0x0F, 0x20, 0xC0     ; mov eax, cr0 (Opcode for MOV R32, CR0)
    or eax, 1               ; Set PE bit (bit 0)
    db 0x0F, 0x22, 0xC0     ; mov cr0, eax (Opcode for MOV CR0, R32)

    ; 5. Far jump to 32-bit Protected Mode
    ; This jump forces the CPU to refresh CS:IP using the GDT, loading the 32-bit Code Segment
    db 0x66, 0xEA           ; 0x66 is the operand-size override for 32-bit offset; 0xEA is JMP FAR opcode
    dd protected32_start    ; 32-bit Offset address of the target routine
    dw 0x08                 ; 16-bit Code Selector (GDT entry at 0x08)

; ------------------------------
; Global Descriptor Table (GDT)
; ------------------------------
align 8
gdt_start:
    dq 0x0000000000000000           ; 0x00 : Null Descriptor (Mandatory)
    ; 0x08 : 32-bit Code Segment (Base 0, Limit 4GB)
    ; Flags: P=1, DPL=0, S=1, Type=Code(10), G=1 (4KB granularity), D/B=1 (32-bit default size)
    dq 0x00CF9A000000FFFF
    ; 0x10 : 32/64-bit Data Segment (Base 0, Limit 4GB)
    ; Flags: P=1, DPL=0, S=1, Type=Data(00), G=1, D/B=1
    dq 0x00CF92000000FFFF
    ; 0x18 : 64-bit Code Segment (Base 0, Limit 4GB)
    ; Flags: P=1, DPL=0, S=1, Type=Code(10), G=1, L=1 (64-bit mode enabled), D/B=0 (must be 0 for L=1)
    dq 0x00AF9A000000FFFF
gdt_end:

gdt_descriptor:
    dw gdt_end - gdt_start - 1      ; Limit (size - 1)
    dd gdt_start                    ; Base Address

; ------------------------------
; Protected 32-bit mode
; ------------------------------
align 16
[BITS 32]
protected32_start:
    cli
    ; 1. Setup 32-bit Segment Registers and Stack
    mov ax, 0x10                ; Load Data Segment Selector (0x10)
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov esp, 0x000A0000         ; Set temporary 32-bit stack pointer
    mov fs, ax
    mov gs, ax

    ; Debug 32-bit: print message
    mov esi, msg32
    call print_string_vga32

    ; --- Prepare Page Tables (PML4, PDPT, PD, PT) for Long Mode ---
    ; Clear 4 pages (16KB) starting at page_tables_base
    mov eax, page_tables_base
    mov edi, eax
    mov ecx, (4 * 4096) / 4     ; 4 pages * 4096 bytes / 4 bytes per DWORD = 4096 DWORDS
    xor eax, eax
    rep stosd                   ; Fill pages with zeros

    ; --- Construct Page Table (PT) - located at base + 0x3000 ---
    ; This PT identity-maps the first 2MB of memory (512 entries * 4KB/page = 2MB)
    mov esi, 0                  ; Page entry index counter
    mov ebx, page_tables_base
    add ebx, 0x3000             ; EBX points to the start of the PT
.pt_loop:
    cmp esi, 512
    je .pt_done
    mov eax, esi
    shl eax, 12                 ; EAX = Physical Address (index * 4096)
    or eax, 0x03                ; Flags: Present (1) + Read/Write (2)
    mov [ebx + esi*8], eax      ; Store low 32 bits (address + flags)
    mov dword [ebx + esi*8 + 4], 0 ; High 32 bits (ignored for addresses < 4GB)
    inc esi
    jmp .pt_loop
.pt_done:

    ; --- Link Tables: PD (Page Directory) -> PT ---
    mov eax, page_tables_base
    add eax, 0x3000             ; PT address
    or eax, 0x03                ; Present + RW flags
    mov [page_tables_base + 0x2000], eax ; PD entry 0 points to PT
    mov dword [page_tables_base + 0x2000 + 4], 0

    ; --- Link Tables: PDPT (Page Directory Pointer Table) -> PD ---
    mov eax, page_tables_base
    add eax, 0x2000             ; PD address
    or eax, 0x03                ; Present + RW flags
    mov [page_tables_base + 0x1000], eax ; PDPT entry 0 points to PD
    mov dword [page_tables_base + 0x1000 + 4], 0

    ; --- Link Tables: PML4 (Page Map Level 4) -> PDPT ---
    mov eax, page_tables_base
    add eax, 0x1000             ; PDPT address
    or eax, 0x03                ; Present + RW flags
    mov [page_tables_base], eax ; PML4 entry 0 points to PDPT
    mov dword [page_tables_base + 4], 0

    ; --- Enable PAE (Physical Address Extension, CR4.PAE bit 5) ---
    mov eax, cr4
    or  eax, (1 << 5)
    mov cr4, eax

    ; --- Enable Long Mode (LME) via MSR (Model Specific Register) ---
    mov ecx, 0xC0000080         ; MSR EFER (Extended Feature Enable Register)
    rdmsr                       ; Read MSR into EDX:EAX
    or eax, (1 << 8)            ; Set LME bit (bit 8) in EAX (low 32 bits)
    wrmsr                       ; Write EAX:EDX back to MSR

    ; --- Load CR3 (PML4 Base Address) ---
    mov eax, page_tables_base
    mov cr3, eax                ; CR3 holds the physical address of the PML4 table

    ; --- Enable Paging (CR0.PG bit 31) ---
    ; This step activates the 64-bit architecture (due to LME being set)
    mov eax, cr0
    or  eax, 0x80000000
    mov cr0, eax

    ; Flush TLB (by reloading CR3) - standard practice after enabling paging
    mov eax, page_tables_base
    mov cr3, eax

    cli ; Keep interrupts disabled

    ; --- Far jump to 64-bit Long Mode ---
    ; After paging is enabled, the code must execute from a 64-bit segment
    db 0xEA                     ; JMP FAR opcode
    dd long_mode_start          ; 64-bit Offset address (still 32-bit effective address here)
    dw 0x18                     ; 64-bit Code Selector (GDT entry at 0x18)

; ---------------------------------
; 32-bit VGA Print Routine
; ---------------------------------
print_string_vga32:
    vga_cursor_addr equ 0x000B8000   ; Constant: Start of VGA Text Buffer memory
    push ebp
    mov ebp, esp
    push edi
    ; Load the starting address of the VGA buffer (or saved cursor position)
    mov edi, vga_cursor_addr 
.ps32:
    mov al, [esi]                   ; Load character from ESI (source string)
    or al, al
    jz .done32                      ; If null terminator, finished
    mov byte [edi], al              ; Write character to screen memory
    mov byte [edi+1], 0x07          ; Write attribute byte (Grey on Black)
    add edi, 2                      ; Move cursor 2 bytes forward
    inc esi                         ; Move source string pointer 1 byte forward
    jmp .ps32
.done32:
    ; The original code has a bug here: it tries to store the cursor position 
    ; back into the EQU constant (vga_cursor_addr). This is non-functional 
    ; but preserved as per instructions.
    ; mov [vga_cursor_pos], edi ; (Corrected version would use a variable)
    pop edi
    pop ebp
    ret

; Variables/Constants for 32-bit mode
page_tables_base equ 0x00091000    ; 4KB aligned memory block for page tables

; ------------------------------
; Long mode (x86_64)
; ------------------------------
align 4096
[BITS 64]
stack64_top equ 0x000A2000      ; Aligned 64-bit stack top address

long_mode_start:
    ; 1. Setup 64-bit Stack and Segment Registers
    mov bx, 0x10                ; Data/Stack Selector
    mov ss, bx                  ; Load SS (Stack Segment)
    mov rsp, stack64_top        ; Load 64-bit Stack Pointer (RSP)
    sub rsp, 8                  ; Align RSP to 16 bytes for x86-64 ABI (though not strictly necessary here, it's good practice)

    ; CRITICAL FIX: Initialize all segment registers to prevent Triple Fault
    mov ds, bx
    mov es, bx
    xor ax, ax                  ; AX=0
    mov fs, ax                  ; FS and GS are often cleared or set up for user space access
    mov gs, ax

    ; 2. Clear VGA Screen (QWORD approach for speed)
    mov rdi, 0x000B8000         ; RDI points to start of VGA buffer
    mov rcx, 2000               ; Number of QWORDs to write (80*25 characters * 2 bytes/char / 8 bytes/QWORD = 2000)
    mov rax, 0x0720072007200720 ; QWORD containing 4 spaces with attributes (0x0720)
.clear_loop:
    mov [rdi], rax              ; Write 8 bytes (4 characters)
    add rdi, 8
    dec rcx
    jnz .clear_loop             ; Loop until RCX is zero

    ; 3. Print First 64-bit Debug Message
    mov rdi, 0x000B8000         ; Reset RDI to start of screen
    mov rsi, msg64
.print64:
    mov al, [rsi]               ; Load character
    or al, al
    je .done64
    mov ah, 0x07                ; Color attribute (Grey on Black)
    mov word [rdi], ax          ; Write character + attribute (WORD)
    add rdi, 2
    inc rsi
    jmp .print64
.done64:
    
    ; 4. Print Second 64-bit Debug Message on the next line
    mov rdi, 0x000B8000 + 160     ; Start of second line (80 chars * 2 bytes/char)
    mov rsi, msg_safe
.print_safe:
    mov al, [rsi]
    or al, al
    je .done_safe
    mov ah, 0x07
    mov word [rdi], ax
    add rdi, 2
    inc rsi
    jmp .print_safe
.done_safe:
    jmp .halt
    
.halt:
    hlt                         ; Halt the processor (if interrupts are disabled)
    jmp .halt                   ; Infinite loop if HLT fails

; ------------------------------
; Messages (String Data)
; ------------------------------
[BITS 16]
msg16      db "Stage2 16-bit start",0x0D,0x0A,0
msg_a20    db "A20 OK",0x0D,0x0A,0
msg_lgdt   db "LGDT done",0x0D,0x0A,0

[BITS 32]
msg32      db "Entered Protected Mode (32-bit)",0

[BITS 64]
msg64      db "Long Mode 64-bit Active!",0
msg_safe   db "System is stable and secure.",0