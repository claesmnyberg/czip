;;
;; Linux system macros, call numbers and values
;; Author: CMN <md0claes@mdstud.chalmers.se>
;;

%ifndef _LINUX_INC
%define _LINUX_INC

[section .text]
   align 4
   __access_linux_kernel:
     int 0x80
     or  eax, eax
     js  __syscall_error
     clc
     ret

   __syscall_error:
    neg  eax
    stc
    ret

;; Syscall macro
%macro system 1
   mov   eax, %1
   call  __access_linux_kernel
%endmacro


;; Syscall numbers ;;;;;;;;;;;;;;;;;;;;

%define SYS_exit                    1
%define SYS_read                    3
%define SYS_write                   4
%define SYS_open                    5
%define SYS_close                   6
%define SYS_unlink                 10

;; Syscall macros ;;;;;;;;;;;;;;;;;;;;;

%macro sys_exit 0
   mov ebx, [esp]
   system SYS_exit
   int   0x80
%endmacro

%macro sys_read 0
   push  edx
   push  ecx
   push  ebx
   mov   ebx, [esp +12]
   mov   ecx, [esp +16]
   mov   edx, [esp +20]
   system SYS_read
   pop   ebx
   pop   ecx
   pop   edx
%endmacro

%macro sys_write 0
   push  edx
   push  ecx
   push  ebx
   mov   ebx, [esp +12]
   mov   ecx, [esp +16]
   mov   edx, [esp +20]
   system  SYS_write
   pop   ebx
   pop   ecx
   pop   edx
%endmacro


;; Open flags
%define O_WRONLY    0x1
%define O_CREAT     0x40
%define O_RDONLY    0x0
%define O_EXCL      0x80
%define O_TRUNC     0x200
%define O_APPEND    0x400

%macro sys_open 0
   push  edx
   push  ecx
   push  ebx
   mov   ebx, [esp +12]
   mov   ecx, [esp +16]
   mov   edx, [esp +20]
   system SYS_open
   pop   ebx
   pop   ecx
   pop   edx
%endmacro

%macro sys_close 0
   push  ebx
   mov   ebx, [esp +4]
   system SYS_close
   pop   ebx
%endmacro

%macro sys_unlink 0
   push  ebx
   mov   ebx, [esp +4]
   system SYS_unlink
   pop   ebx
%endmacro

%endif
