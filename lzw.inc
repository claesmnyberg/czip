;;
;; Implementation of the Lempel Ziv Welch
;; loss less compression algorithm
;; This is a simple example, that uses a fixed
;; table length that is keeped during the whole
;; compression, why files with alot of random data
;; might not be that compressed ...
;;
;; Author: CMN <md0claes@mdstud.chalmers.se>
;;
;;
%ifndef _LZW_INC
%define _LZW_INC

;;
;; Every string is represented by 12 bits (2^12 = 4096)
;;
%define TABLE_SIZE          4096
%define BIT_CODE_LEN        12

;;
;; String Table
;; A string represents an arbitrary length
;; of bytes (in this case, not ended with a zero byte).
;;
;; typedef struct _StrEnt {
;;     u_int num_prebytes;      /* Number of bytes before this */
;;     struct _StrEnt *prebyte; /* Pointer to entry that holds byte before this */
;;     u_char endbyte;          /* This byte */
;; } StrEnt;
;;
%define STRING_ENTRY_SIZE	(4+4+1)


;;
;; The code table
;;
;; string_table:
;; Every string is represented by 12 bits (2^12 = 4096).
;; First 256 (0-255) represents the byte with its index
;;
;; index_table:
;; The purpose with this array is to speed up the search for a string
;; by keeping indexes of strings in string_table that ends with the
;; indexed value. If string in string_table[n] (where n>255) ends
;; with byte 'A', then will index_table['A'] look like [n|0] (ends with 0).
;;
;; typedef struct _CodeTable {
;;
;;    StrEnt *string_table[TABLE_SIZE];
;;    int index_table[256][TABLE_SIZE];
;;
;; } CodeTable;
;;
%define STRING_TABLE_SIZE	(STRING_ENTRY_SIZE * TABLE_SIZE)
%define INDEX_TABLE_SIZE	(256 * TABLE_SIZE)

%endif
