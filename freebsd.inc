;;
;; FreeBSD system macros, call numbers and values
;; Author: CMN <md0claes@mdstud.chalmers.se>
;;

%ifndef _FREEBSD_INC
%define _FREEBSD_INC


[section .text]
    align 4
    __access_freebsd_kernel:
        int 0x80
        ret

;; Syscall macro
%macro system 1
    mov eax, %1
    call __access_freebsd_kernel
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
    system SYS_exit
%endmacro

%macro sys_read 0
    system SYS_read
%endmacro

%macro sys_write 0
    system SYS_write
%endmacro


;; Open flags
%define O_WRONLY    0x1
%define O_CREAT     0x200
%define O_RDONLY    0x0
%define O_EXCL      0x800
%define O_TRUNC     0x400
%define O_APPEND    0x8

%macro sys_open 0
    system SYS_open
%endmacro

%macro sys_close 0
    system SYS_close
%endmacro

%macro sys_unlink 0
	system SYS_unlink
%endmacro

%endif
