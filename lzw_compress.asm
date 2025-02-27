
;;
;; Compress file.
;; Returns 1 on success and -1 on error.
;;

%include "lzw.inc"
%include "system.inc"

[section .bss]
   string_table resb   STRING_TABLE_SIZE       ; The string table
   index_table  resb   INDEX_TABLE_SIZE        ; The index table
   string       resb   48                      ; String
   char         resb   1                       ; byte

[section .text]
   extern bit_putb
   global lzw_compress

;;  
;;   Registers
;;   eax   - Code (return value from get_code)
;;   ebx   - Saved code
;;   ecx   - Current length of string
;;   edx   - 
;;   esi   - 
;;   edi   - Index of next available string table entry
;;

   lzw_compress:
         push    ebp
         mov     ebp, esp
         push    edi
         push    ebx                           ; Save registers 
         push    ecx                           ; Someone told me that this 
         push    esi                           ; was the fastest way ;-)
         sub     esp, 4                        ; Create Local variables
         mov     [esp], dword 0                ; slen = 0 (Length of string)         
         xor     edi, edi                      ; index = 0
      
      ;; Set the first 256 entries to represent byte values 0-255
      .set_bytes:
         mov     [string_table+(edi*9)], dword 0      ; num_prebytes = 0
         mov     [string_table+(edi*9+4)], dword 0    ; prebyte = NULL
         mov     [string_table+(edi*9+8)], di         ; endbyte = index         
         inc     edi
         cmp     edi, dword 256                       ; index < 256 ?
         jl      .set_bytes            

      ;; Read first byte 
         push    dword 1
         push    dword string                  ; &string[0]
         push    dword [ebp +8]                ; in file
         sys_read                              ; string[0] = getchar()
         add     esp, 12
         cmp     eax, 1
         jne     near .err                     ; Error reading first byte
         inc     dword [esp]                   ; slen;
         mov     al, [string]
         mov     [char], al                    ; byte = string[0]
         mov     bl, al                        ; saved code = byte

      ;; Read and encode as long as there are bytes left
      .encode:
         push    dword 1
         push    dword char                    ; byte
         push    dword [ebp +8]                ; in file
         sys_read 
         add     esp, 12
         cmp     eax, 0xffffffff               ; Read returned -1
         je      near .err         
         cmp     eax, 0
         je      near .finished                ; All bytes read 

      ;; Check if code exists for string + byte
         mov     eax, TABLE_SIZE
         mov     esi, [char]
         mul     esi
         add     eax, index_table
         push    dword eax                     ; &index_table[byte]
         push    dword string_table            ; &string_table[0]
         push    dword [esp +8]                ; slen
         push    dword string                  ; &string[0]
         call    get_code
         add     esp, 16
         or      eax,eax
         jns     near .code_existed   

      ;; Code didn't exist, Write code for string
         push    dword [ebp +12]               ; out file
         push    dword ebx                     ; saved code
         push    dword BIT_CODE_LEN      
         call    bit_putb
         add     esp, 12

      ;; Add entry in table for string + char if there is space left
         cmp     edi, (TABLE_SIZE -1)
         jg      .after_addentry   
         mov     ecx, [esp]                     ; slen
         mov     [string_table+(edi*9)], ecx    ; num_prebytes = slen
         mov     eax, dword 9
         mul     ebx
         add     eax, string_table              ; &string_table[saved_code]
         mov     [string_table+(edi*9 +4)], eax ; prebyte = &string_table[saved_code]
         mov     al, [char]
         mov     [string_table+(edi*9 +8)], al  ; endbyte = byte    

      ;; Save index of string that ends with this byte
         mov     eax, TABLE_SIZE
         mov     esi, [char]
         mul     esi
         add     eax, index_table              ; &index_table[byte]
         
      .count:                                  ; Find first zero index
        cmp    [eax], dword 0 
        je     .done
        add    eax, byte 4
        jmp    short .count

      .done:
        mov     [eax], edi                     ; Store index
        inc     edi                            ; index++

      ;; string = saved code = byte 
      .after_addentry:
         mov     ebx, [char]                   ; saved code = byte
         mov     [string], ebx                 ; string[0] = byte
         mov     [esp], dword 1                ; slen = 1
         jmp     .encode                       ; start all over again
            
      ;; Code existed, save code for string + byte
      ;; and add byte to string
      .code_existed:
         mov     ebx, eax                      ; saved code = code
         mov     eax, [char]
         mov     ecx, dword [esp]
         mov     [string + ecx], eax           ; string[slen] = byte
         inc     dword [esp]                   ; slen++
         jmp     .encode                       ; start all over again

      ;; Write code for remaining string and exit
      .finished:
         push    dword [ebp +12]               ; out file
         push    dword ebx                     ; saved code
         push    dword BIT_CODE_LEN      
         call    bit_putb
         add     esp, 12
         mov     eax, dword 1                  ; return 1
         jmp     .exit

      .err:
         mov     eax, 0xffffffff               ; return -1

      .exit:   
         add     esp, 4                        ; Remove local variables   
         pop     edi
         pop     esi
         pop     ecx
         pop     ebx
         mov     esp, ebp                      ; We are done
         pop     ebp
         ret


;;
;; Get encoded value for string + byte
;; Returns the code on success, -1 if
;; string + code doesn't exist in table.
;;
;;  esi = index
;;  ebx = string[table]-> ...
;;  edx = num_rebytes
;;
   get_code:
        push     esi
        push     ecx
        push     edx
        push     ebx
        push     edi
        mov      esi, dword [esp +36]          ; &index[0]
        sub      esi, dword 4

   ;; Compare all strings in index list
   .scan_for_code:
        add      esi, dword 4                  ; index++
        cmp      [esi], dword 0
        je       .nocode   
        mov      eax, dword 9
        mul      dword [esi]
        add      eax, [esp +32]                ; string_table[*index]
        mov      ebx, eax
        mov      edx, [ebx]                    ; string_table[*index]->num_prebytes
        cmp      edx, dword [esp +28    ]      ; num_prebytes == slen ?
        jne      .scan_for_code                ; Try next index

   ;; Compare strings
   .cmp_strings:
       cmp       edx, dword 0x01               ; while (len > 0) 
        js       .scan_for_code
        mov      edi, dword [ebx +4]
        mov      ebx, edi                      ; strent = strent->prebyte
        xor      ecx, ecx
        mov      edi, [esp +24]                ; &string[0]
        mov      cl, [edi +edx -1]             ; string[len -1]
        cmp      cl, byte [ebx +8]             ; string[len -1] == prebyte->endbyte ?
        jne      .scan_for_code 
        dec      edx                           ; len--
        cmp      edx, dword 0x00
        je       .code_found
        jmp      .cmp_strings

   ;; Code found, return index
   .code_found:
        mov      eax, [esi]
        jmp      .finish
   
   ;; No code found, return -1
   .nocode:
        mov      eax, dword 0xffffffff

   .finish:
        pop      edi
        pop      ebx
        pop      edx
        pop      ecx
        pop      esi
        ret
