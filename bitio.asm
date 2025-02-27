;;
;; Bitwise IO functions
;; Author: CMN <md0claes@mdstud.chalmers.se>
;;

%include "system.inc"

%define READ_ONLY           1
%define WRITE_ONLY          2

%define DEFAULT_PERMS   0x180   ; (0600 octal)

;struc BITFILE
;    _buffer:   resb 1
;    _bitcount: resb 1
;    _flags:    resw 1
;    _fd:       resd 1
;endstruc

;; Temporary solution ...
[section .bss]
   BITFILE_BSS   resb 8

[section .text]
   global bit_close
   global bit_getb
   global bit_putb
   global bit_open

;;
;;
;; Open bitfile
;;
;; argv[1] - Character, 'r' for reading and 'w' for writing.
;;           On writing the file is truncated to zero length,
;;           or created if it doesn't exist.
;; argv[0] -  Path to the the file to open
;;
;; Returns 0 on error
;;
  extern debug
   bit_open:
        push     edx
        push     ebx
        mov      ebx, BITFILE_BSS
        mov      edx, [esp +16]        ; mode pointer
        cmp      edx, dword 'r'    
        je       .open_read  
        cmp      edx, dword 'w'
        jne      .err
  
   ;; Open for write only
        push     dword DEFAULT_PERMS
        push     dword (O_WRONLY | O_CREAT | O_TRUNC) 
        push     dword [esp +20]       ; Path
        sys_open
        jc       .err
        add      esp, 12
        mov      [ebx +2], word WRITE_ONLY
        jmp      .exit

   ;; Open for read only
   .open_read:
        push     dword 0x0000          ; Dummy
        push     dword O_RDONLY
        push     dword [esp +20]       ; Path
        sys_open
        jc       .err
        add      esp, 12
        mov      [ebx +2], word READ_ONLY
        jmp      .exit

   .err:
        add      esp, 12
        xor      eax, eax
        jmp      short .finish

   .exit:
        mov      [ebx +4], eax         ; File descriptor
        mov      [ebx], byte 0         ; Bitbuffer = 0
        mov      [ebx +1], byte 0      ; Bitcount = 0
        mov      eax, ebx              ; Return BITFILE pointer

   .finish:
        pop      ebx
        pop      edx
        ret


;;
;; Write bits to BITFILE
;;
;; argv[2] - Pointer to a BITFILE
;; argv[1] - Bits to write
;; argv[0] - Number of bits to write
;; 
;; Returns 1 on success, -1 on error
;;
   bit_putb:
        push     edx
        push     ecx
        push     esi
        sub      esp, 4                 ; Local variable
        mov      esi, [esp +28]         ; BITFILE
        mov      edx, [esp +24]         ; Bits to write
        cmp      dword [esp +20], 32    ; Number of bits to write > 32 ?
        jg       near .err

   ;; Check that file is opened for writing
        cmp      [esi +2], word WRITE_ONLY
        jne      near .err

   ;; Flush buffer if there are bits left
        cmp      [esi +1], byte 0
        je       .add_bits   
        mov      eax, [esp +20]         ; Number of bits to write
        add      al, byte [esi +1]      ; bitcount + Number of bits to write
        cmp      al, 8
        js       .add_bits      
        mov      cl, 8            
        sub      cl, byte [esi +1]      ; 8 - bitcount
        shl      byte [esi], cl         ; buffer <<= (8- bitcount)
        mov      al, cl
        mov      cl,   [esp +20]        ; Number of bits to write
        sub      [esp +20], al          ; Bits to write -= (8 - bitcount)
        sub      cl, al                 ; nbits - (8 - bitcount)

        shr      edx, cl                ; Bits to write >> cl
        or       byte [esi], dl         ; buffer |= Bits to write >> cl
        push     dword 1
        push     esi                    ; Bit buffer
        push     dword [esi +4]         ; File descriptor
        sys_write
        add      esp, 12
        mov      [esi], byte 0          ; buffer = 0
        mov      [esi +1], byte 0       ; bitcount = 0
        jmp      .write_rest   

   ;; Add bits to buffer
   .add_bits:
        cmp      [esp +20], byte 7      ; Number of bits to write < 8 ?
        jg       .write_rest
        mov      ecx, [esp +20]         ; Number of bits to write
        shl      byte [esi], cl         ; buffer <<= bits to write
        mov      eax, 0xffffffff        ; ~0
        mov      cl, 8            
        sub      cl, [esp +20]          ; 8 - Number of bits to write
        shr      eax, cl
        and      eax, edx
        or       byte [esi], al         ; buffer |= bits to write & ~0 >> (8 - nbits))
        mov      eax, [esp +20]         ; Number of bits to write
        add      byte [esi +1], al      ; bitcount += Number of bits to write
        mov      [esp +20], dword 0     ; Number of bits to write = 0

   ;; Write remaining octets from word
   .write_rest:
        mov      edx, [esp +24]         ; Bits to write
        cmp      [esp +20], dword 8     ; Bits left < 8 ?
        js       .save_bits
        mov      ecx, [esp +20]         ; Number of bits to write
        sub      cl, 8
        shr      edx, cl
        mov      [esp], edx             ; Write buffer
        mov      eax, esp
        push     dword 1
        push     eax                    ; Bits to write
        push     dword [esi +4]         ; File descriptor
        sys_write
        add esp, 12
        sub      dword [esp +20], 8     ; Number of bits to write -= 8
        jmp      .write_rest

   ;; Save bits left
   .save_bits:
        cmp      [esp +20], dword 0
        je       .exit
        mov      eax, [esp +20]
        mov      [esi +1], al           ; Bitcount = nbits
        mov      eax, [esp +24]
        mov      [esi], al              ; Bitbuf = Bits to write
        jmp      .exit
      
   .err:
        mov      eax, 0xffffffff
        jmp      .finish
   
   .exit:
        mov      eax, 1

   .finish:
        add      esp, 4
        pop      esi
        pop      ecx
        pop      edx
        ret

      
;;
;; Get next bit from BITFILE opened for reading. 
;; On success the next bit is returned, 
;; on error 2 is returned.
;; On end-of-file EOF is returned.
;;   
   bit_getb:
        push     edx
        push     ecx
        push     esi
        sub      esp, 4                    ; Next byte variable
        mov      esi, [esp +20]            ; BITFILE
      
   ;; Check that file is opened for reading
        cmp      [esi +2], word READ_ONLY
        jne      .no_read
        cmp      [esi +1], byte 0          ; Are there bits left ?
        je       .get_next_byte
   
   ;; Return next bit in buffer
   .get_next_bit:
        xor      eax, eax
        mov      al, [esi]                 ; buffer
        shr      al, 7                     ; buffer >> 7
        shl      byte [esi], 1
        dec      byte [esi+1]              ; bitcount--
        jmp      .finish

   ;; Get next byte from file
   .get_next_byte:
        mov      eax, esp
        push     dword 1
        push     dword eax
        push     dword [esi +4]            ; BITFILE
        sys_read
        add      esp, 12
        cmp      eax, 0
        je       .eof                      ; EOF 
        or       eax, eax
        js       .err                      ; Error
   
        xor      eax, eax
        mov      al, [esp]
        shl      al, 1   
        mov      [esi], al                 ; bitbuffer = (read << 1)
        mov      [esi+1], byte 7           ; bits left = 7
        mov      al, [esp]
        shr      al, 7
        jmp      .finish
   
   .no_read:
        mov      eax, dword 2
        jmp      .finish

   .eof:
        mov      eax, EOF
        jmp      .finish

   .err:
        mov      eax, 2

   .finish:
        add      esp, 4
        pop      esi
        pop      ecx
        pop      edx
        ret


;;
;; Close BITFILE
;; If BITFILE is writable the buffer
;; is written to file with missing bits set to zero.
;; Returns 0 on success, -1 on error.
;;
;; Takes a BITFILE as argument
;;
   bit_close:
        push     ebx
        push     ecx
        mov      ebx, [esp +12]      ; argv[0], BITFILE
        cmp      [ebx +2], word WRITE_ONLY
        je       .flush_bits
        jmp      .finish   

   ;; Flush remaining bits in buffer
   .flush_bits:
        cmp      [ebx +1], byte 0
        je       .finish            ; No bits left in buffer

   ;; Pad with zero bits
        xor      eax, eax
        mov      al, byte [ebx]     ; Bit buffer
        mov      cl, 8
        sub      cl, [ebx +1]       ; 8 - bitcount
        shl      al, cl             ; pad with zero bits 
        mov      [ebx], al

   ;; Write buffer
        push     dword 1
        push     dword ebx           ; Bit buffer
        push     dword [ebx +4]      ; File descriptor
        sys_write
        add      esp, 12

   .finish:
        push     dword [ebx +4]      ; File descriptor
        sys_close
        add      esp, 4
        pop      ecx
        pop      ebx
        ret   
