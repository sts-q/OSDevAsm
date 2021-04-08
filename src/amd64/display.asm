;============================================================================

; :file:   display.asm

;============================================================================
; :chapter:   display

;------------------------------------------
%macro clear_screen 0 ; ( -- )
               call clear_screenF
               %endmacro
clear_screenF: 
               mov eax, vga_mem
               mov ebx, [vga_attr]
               mov ecx, 2000
       .loop:
               mov [eax], bx
               add eax, 2
               dec ecx
               cmp ecx, 0
               jnz             .loop
               ret


;------------------------------------------
%macro cprint 1-* ; ( chr -- )
       %rep %0
               mov eax, %1
               call cprintF
       %rotate 1
       %endrep
%endmacro
cprintF:  
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


%macro spc 0  ; ( -- )
               cprint 32
               %endmacro


;------------------------------------------
%macro printat 2  ; ( line col -- )
               mov eax, %1
               mov ebx, %2
               call printatF
               %endmacro
printatF:
               mov [vga_line], eax
               mov [vga_col],  ebx
               ret


;------------------------------------------
printattrF:
               shl eax, 8
               mov [vga_attr], eax
               ret
%macro ink_std 0
               mov eax, 0x1f
               call printattrF
               %endmacro
%macro ink_headline 0
               mov eax, 0x2a
               call printattrF
               %endmacro
%macro ink_comment 0
               mov eax, 0x17
               call printattrF
               %endmacro
%macro ink_error 0
               mov eax, 0x50
               call printattrF
               %endmacro

               
;------------------------------------------
%macro abc 0
               call abcF
               %endmacro
abcF:
               printat 0, 20
               cprint 65
               cprint 66
               ink_headline
               cprint 67
               spc
               cprint 67
               cprint 67
               spc
               cprint 67
               ink_std
               cprint 66
               cprint 65

               printat 24, 20
               cprint 65
               cprint 66
               ink_comment
               cprint 67
               spc
               cprint 67
               cprint 67
               spc
               cprint 67
               ink_std
               cprint 66
               cprint 65
               ret


;============================================================================

main:
               ink_std
               clear_screen  
               abc
               ret

;============================================================================
