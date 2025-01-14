; References:
;   - http://wiki.osdev.org/Bare_Bones
;   - https://davidad.github.io/blog/2014/02/18/kernel-from-scratch/ (David A. Dalrymple)

use32

extern osdevasm_main    ; this is our kernel's entry point

; Setting up the Multiboot header - see GRUB docs for details
MBALIGN         equ     1<<0                    ; Align loaded modules on page boundaries
MEMINFO         equ     1<<1                    ; Provide memory map
;;; GRAPHICS    equ     1<<2
GRAPHICS        equ     1<<0                    ; std 80x25
FLAGS           equ     MBALIGN | MEMINFO | GRAPHICS    ; This is the Multiboot 'flag' field
MAGIC           equ     0x1BADB002              ; 'magic number' lets bootloader find the header
CHECKSUM        equ     -(MAGIC + FLAGS)        ; Checksum required to prove that we are multiboot
STACK_SIZE      equ     0x4000                  ; Stack size is 16KiB
VBE_MODE        equ     0
VBE_WIDTH       equ     1024
VBE_HEIGHT      equ     768
VBE_DEPTH       equ     32


; The multiboot header must come first.
section .multiboot

; Multiboot header must be aligned on a 8-byte boundary
align 8

multiboot_header:
dd MAGIC
dd FLAGS
dd CHECKSUM
dd 0
dd 0
dd 0
dd 0
dd 0
dd VBE_MODE
dd VBE_WIDTH
dd VBE_HEIGHT
dd VBE_DEPTH

; The beginning of our kernel code
section .text

global multiboot_entry
multiboot_entry:
        mov esp, stack + STACK_SIZE     ; set up the stack
        mov [magic], ebx                ; multiboot magic number
        mov [multiboot_info], eax       ; multiboot data structure

        ;------------
        ; Now we're going to set up the page tables for 64-bit mode.
        ; Since this is a minimal example, we're just going to set up a single page.
        ; The 64-bit page table uses four levels of paging,
        ;    PML4E table => PDPTE table => PDE table => PTE table => physical addr
        ; You don't have to use all of them, but you have to use at least the first
        ; three. So we're going to set up PML4E, PDPTE, and PDE tables here, each
        ; with a single entry.
%define PML4E_ADDR 0x8000
%define PDPTE_ADDR 0x9000
%define PDE_ADDR 0xa000
        ; Set up PML4 entry, which will point to PDPT entry.
        mov dword eax, PDPTE_ADDR
        ; The low 12 bits of the PML4E entry are zeroed out when it's dereferenced,
        ; and used to encode metadata instead. Here we're setting the Present and
        ; Read/Write bits. You might also want to set the User bit, if you want a
        ; page to remain accessible in user-mode code.
        or dword eax, 0b011  ; Would be 0b111 to set User bit also
        mov dword [PML4E_ADDR], eax
        ; Although we're in 32-bit mode, the table entry is 64 bits. We can just zero
        ; out the upper bits in this case.
        mov dword [PML4E_ADDR+4], 0
        ; Set up PDPT entry, which will point to PD entry.
        mov dword eax, PDE_ADDR
        or dword eax, 0b011
        mov dword [PDPTE_ADDR], eax
        mov dword [PDPTE_ADDR+4], 0
        ; Set up PD entry, which will point to the first 2MB page (0).  But we
        ; need to set three bits this time, Present, Read/Write and Page Size (to
        ; indicate that this is the last level of paging in use).
        mov dword [PDE_ADDR], 0b10000011
        mov dword [PDE_ADDR+4], 0

        ; Enable PGE and PAE bits of CR4 to get 64-bit paging available.
        mov eax, 0b10100000
        mov cr4, eax

        ; Set master (PML4) page table in CR3.
        mov eax, PML4E_ADDR
        mov cr3, eax

        ; Set IA-32e Mode Enable (read: 64-bit mode enable) in the "model-specific
        ; register" (MSR) called Extended Features Enable (EFER).
        mov ecx, 0xc0000080
        rdmsr ; takes ecx as argument, deposits contents of MSR into eax
        or eax, 0b100000000
        wrmsr ; exactly the reverse of rdmsr

        ; Enable PG flag of CR0 to actually turn on paging.
        mov eax, cr0
        or eax, 0x80000000
        mov cr0, eax


        ; Load Global Descriptor Table (outdated access control, but needs to be set)
        lgdt [gdt_hdr]

        ; Jump into 64-bit zone.
        jmp 0x08:_64_bits

bits 64
_64_bits:
;;;     call osdevasm_main              ; calling the kernel
        call main                       ; calling main:  display.asm

hang:
        hlt                             ; something bad happened, machine halted
        jmp hang


%include "display.asm"


; Global descriptor table entry format
; See Intel 64 Software Developers' Manual, Vol. 3A, Figure 3-8
; or http://en.wikipedia.org/wiki/Global_Descriptor_Table
%macro GDT_ENTRY 4
        ; %1 is base address, %2 is segment limit, %3 is flags, %4 is type.
        dw %2 & 0xffff
        dw %1 & 0xffff
        db (%1 >> 16) & 0xff
        db %4 | ((%3 << 4) & 0xf0)
        db (%3 & 0xf0) | ((%2 >> 16) & 0x0f)
        db %1 >> 24
%endmacro
%define EXECUTE_READ 0b1010
%define READ_WRITE 0b0010
%define RING0 0b10101001 ; Flags set: Granularity, 64-bit, Present, S; Ring=00
                   ; Note: Ring is determined by bits 1 and 2 (the only "00")

; Global descriptor table (loaded by lgdt instruction)
gdt_hdr:
        dw gdt_end - gdt - 1
        dd gdt
gdt:
        GDT_ENTRY 0, 0, 0, 0
        GDT_ENTRY 0, 0xffffff, RING0, EXECUTE_READ
        GDT_ENTRY 0, 0xffffff, RING0, READ_WRITE
        ; You'd want to have entries for other rings here, if you were using them.
gdt_end:

section .bss nobits align=8
; Reserve initial kernel stack space
stack:          resb STACK_SIZE ; reserve 16 KiB stack
multiboot_info: resd 1          ; we will use this in kernel's main
magic:          resd 1          ; we will use this in kernel's main


section .data

global kernel_stack_bottom
kernel_stack_bottom:
        dd stack

global kernel_stack_size
kernel_stack_size:
        dd STACK_SIZE


vga_mem:                       equ 0xb8000
vga_line:                      dd 0
vga_col:                       dd 0
vga_attr:                      dd 0                    ; vga_attr := attr << 8  -->  bx := chr+attr; vga[]:=bx

kbd_buffer:                    db 64
kbd_buffer_end:

kbd_read_ptr:                  dd 0
kbd_write_ptr:                 dd 0

