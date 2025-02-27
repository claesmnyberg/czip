;;
;; UNIX definitions
;;

%ifndef _SYSTEM_H
%define _SYSTEM_H

%ifdef FREEBSD
    %include "freebsd.inc"
%elifdef LINUX
    %include "linux.inc"
%endif 

%define EOF                0xffffffff

%define STDIN_FILENO                0
%define STDOUT_FILENO               1
%define STDERR_FILENO               2

%endif
