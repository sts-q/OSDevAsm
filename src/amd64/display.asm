;============================================================================

; :file:   display.asm

;============================================================================
; :chapter:   display

%macro clear_screen 1
               mov eax, %1
               call clear_screenF
               %endmacro
clear_screenF: ; ( attr -- )
               shl eax, 8
               mov [vga_attr], eax
               mov ebx, vga_mem

               mov ecx, 2000
       .loop:
               mov [ebx], ax
               add ebx, 2
               dec ecx
               cmp ecx, 0
               jnz             .loop
               ret


%macro cprint 1
               mov eax, %1
               call cprintF
               %endmacro
cprintF:  ; ( chr -- )
               push rax
               mov eax, [vga_line]
               mov ebx, 80
               imul ebx
               add eax, [vga_col]
               shl eax, 1
               add eax, vga_mem
               pop rbx
               add ebx, [vga_attr]
               mov [eax], bx
               inc dword [vga_col]
               ret


%macro spc 0
               cprint 32
               %endmacro


abcF:
               cprint 65
               cprint 66

               mov eax, 0x2a00
               mov [vga_attr], eax
               cprint 67
               spc
               cprint 67
               mov eax, 0x1f00
               mov [vga_attr], eax

               cprint 66
               cprint 65
               ret


;============================================================================

main:
               clear_screen 0x1F               ; white on blue
               call abcF
               ret

;============================================================================
