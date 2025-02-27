;;
;; Decompress file.
;; Returns 1 on success and -1 on error.
;;
;;   Registers
;;   eax   -
;;   ebx   - Old code
;;   ecx   -
;;   edx   -
;;   esi   - New Code
;;   edi   - Index of next available string table entry
;;

%include "lzw.inc"
%include "system.inc"

[section .bss]
   string_table  resb STRING_TABLE_SIZE        ; The string table
   string        resb 48                       ; Decoded string
   char          resb 1                        ; byte
   slen          resd 1                        ; Slen, length of string
   old_code      resd 1
   new_code      resd 1

[section .text]
   extern bit_getb
   global lzw_decompress

   lzw_decompress:
         push    ebp
         mov     ebp, esp
         push    edi
         push    ebx
         push    ecx
         push    esi
         xor     edi, edi                      ; Index = 0

      ;; Set the first 256 entries to represent byte values 0-255
      .set_bytes:
         mov     [string_table+(edi*9)], dword 0   ; num_prebytes = 0
         mov     [string_table+(edi*9+4)], dword 0 ; prebyte = NULL
         mov     [string_table+(edi*9+8)], di      ; endbyte = index
         inc     edi
         cmp     edi, dword 256                    ; index < 256 ?
         jl      .set_bytes

      ;; Get first code, must be a byte value
         push    dword [ebp +8]                ; argv[0], in file (BITFILE)
         call    get_nextcode
         add     esp, 4
         mov     [old_code], eax               ; old_code = first code 
         cmp     eax, dword 255
         jg      near .err                     ; Not a byte value
         cmp     eax, 0
         js      near .err                     ; I/O Error

      ;; Write first code 
         push    dword 1
         push    dword old_code
         push    dword [ebp +12]               ; argv[1], out file
         sys_write
         add      esp, 12

      ;; Read until EOF
      .decode:
         push    dword [ebp +8]                ; argv[0], in file (BITFILE)
         call    get_nextcode
         add     esp, 4
         cmp     eax, EOF                      ; EOF
         je      near .finished
         mov     [new_code], eax               ; New code
         mov     ebx, [new_code]
         mov     esi, 0xffffffff               ; Set esi to -1
         cmp     ebx, edi                      ; Is new code in table ?
         jl      .get_string_new_code          ; New Code existed in table, get the string

      ;; Get string for old code
      .get_string_old_code:
         mov     ebx, [old_code]
         mov     esi, ebx

      ;; Get string for new code
      .get_string_new_code:
         mov     eax, dword 9
         mul     ebx
         add     eax, string_table             ; &string_table[new code]
         push    dword eax
         push    dword string
         push    dword slen
         call    get_string
         add     esp, 12   
         or      esi, esi                       ; Check if code was old or new
         js      .write_string      

      ;; If we got string for old_code add byte to end of string
         mov     al, [char] 
         mov     ebx, [slen]
         mov     [string +ebx], al             ; string[slen] = byte
         inc     dword [slen]                  ; slen++

      ;; Write string to file
      .write_string:
         push    dword [slen]                  ; length
         push    dword string                  ; &string[0]
         push    dword [ebp +12]               ; argv[1], out file
         sys_write
         add     esp, 12

      ;; Add entry to table for old code + byte if there is space left
      .add_entry:
         mov     al, byte [string]
         mov     [char], al                    ; .. but first: byte = string[0]
         cmp     edi, (TABLE_SIZE -1)
         jg      .continue
         mov     eax, dword 9
         mov     ebx, [old_code]
         mul     ebx
         add     eax, string_table             ; &string_table[old code]
         mov     ebx, [eax]
         inc     ebx
         mov     [string_table+(edi*9)], ebx   ; num_prebytes = table[old_code]->num_pbytes +1
         mov     [string_table+(edi*9+4)], eax ; prebyte = &string_table[saved_code]
         mov     al, [char]
         mov     [string_table+(edi*9+8)], al  ; endbyte = byte
         inc     edi

      ;; Set old code to new code and continue
      .continue:
         mov     esi, [new_code]
         mov     [old_code], esi               ; old code = new code
         jmp     .decode
      
      .err:
         mov     eax, 0xffffffff               ; return -1
         jmp     .exit
      
      .finished:
         mov     eax, 1

      .exit:
         pop     edi
         pop     esi
         pop     ecx
         pop     ebx
         mov     esp, ebp                      ; We are done
         pop     ebp
         ret

;;
;; Get next code from compressed file
;; returns code on success, EOF if
;; end of file were reached
;;
   get_nextcode:
        push     edi
        push     ecx
        push     ebx
        xor      edi, edi              ; Code to return
        mov      ebx, (BIT_CODE_LEN-1) ; Number of bits to get
         
      .getbits:
        cmp      ebx, dword 0
        js       .ret_code           ; All bits added
        push     dword [esp +16]     ; argv[0], BITFILE
        call     bit_getb            ; Get next bit
        add      esp, 4
        or       eax, eax
        js       .ret_EOF            ; bit_getb returned EOF
        mov      cl, bl              ; Why is ecx manipulated when using call!?
        shl      eax, cl             ; (c << i)
        or       edi, eax            ; code |= (c << i)
        dec      ebx
        jmp      .getbits

      .ret_EOF:
        jmp      .finished

      .ret_code:
        mov      eax, edi            ; return code
   
      .finished:
        pop      ebx
        pop      ecx
        pop      edi
        ret


;;
;; Get string value for code 
;; len is set to the length of bytes
;; stored in string
;;
;;
;; argv[2]  string_table
;; argv[1]  string
;; argv[0]  slen
;;
;;  esi - index
;;  ebx - strent
;;  edi - string
;;
   get_string:
        push     esi
        push     edx
        push     ebx
        push     edi
        mov      ebx, [esp +28]      ; strent
        mov      esi, [ebx]          ; index
        mov      edx, [esp +20]      
        mov      [edx], esi
        inc      dword [edx]         ; Set slen to num_prebytes +1
        mov      edi, [esp +24]      ; &string[0]
        mov      al, byte [ebx +8]
        mov      [edi +esi], al      ; string[index] = strent->endbyte
        dec      esi                 ; index--

   ;; Add all bytes to string
   .addbytes:
        cmp      esi, 0
        jl       .finish
        mov      edx, dword [ebx +4]
        mov      ebx, edx            ; strent = strent->prebyte
        mov      al, byte [ebx +8]
        mov      [edi +esi], al      ; string[index] = strent->endbyte
        dec      esi                 ; index--
        jmp      .addbytes
   
   .finish:
        pop      edi
        pop      ebx
        pop      edx
        pop      esi
        ret
