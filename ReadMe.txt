-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
       czip - A Lempel Ziv Welch compressing program in x86 assembler
              Author: Claes M Nyberg <cmn@signedness.org>
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
             
             0. Introduction
                
             1. Files
             
             2. LZW algorithm
    
             3. Implementation
    

0. Introduction -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    The intention when writing this program was to learn assembly, 
    not to create a powerful compressing program.
    This program uses a fixed size of bits (12) to represent a string.
    
	A more powerful program would for example use a dynamic amount of bits 
    depending on the size of the current code to output, and devide the 
    compressed file into blocks of huffman trees. 
    But that's another program. :-)
	Oh, and you need nasm to get this program running (http://nasm.2y.net/).
	
    References: http://dogma.net/markn/articles/lzw/lzw.htm
                http://www.11a.nu/lempelziv.htm
                http://www.int80h.org/bsdasm/
                http://www.octium.net/oldnasm/docs/nasmdoc0.html


1. Files -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    Makefile              - Compiling rules, type 'make' for usage
    README                - This file
    bitio.asm             - Bitwise I/O functions
    freebsd.inc           - FreeBSD specific definitions
    linux.inc             - Linux specific definitions
    lzw.inc               - Definitions used by the two files below
    lzw_compress.asm      - Procedures for compressing 
    lzw_decompress.asm    - Procedures for decompressing
    main.asm              - The main program that ties everything together
    system.inc            - System definitions, this file actually
                            includes 'freebsd.inc' or 'linux.inc', depending
                            on the compiling definition.

2. LZW algorithm -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-

    The Lempel Ziv algorithm was published in 1977 (LZ77) and later refined by 
    Terry Welch (LZW) in 1984.
    
    All strings are stored in a table, where the first 256 entries represents
    the byte values 0-255. The flow of the compression/decompression could be 
    described like this:

    Flow of compression: 
    Char is a single byte and string is variable length of bytes 
    ( _not_ terminated by a NULL byte).


                                       (start)
                                          |
                           [Input first byte, store in String]
           ______________________________>| 
           |                              |
           |                 [Input next byte, store in Char]
           |                              |
           |                 [Is String + Char in table?]
           |                              |     
           |           No  _______________|________________  Yes
           |               |                              |
           |     [Write Code for String]        [String = String + Char]
           |               |                              |
           | [Add table entry for String+Char]            |
           |               |                              |
           |        [String = Char]                       |
           |               |______________________________|
           |                              |
           --------- Yes -----------[Bytes left?]
                                          | No
                                [Write code for String]
                                          |
                                        (Done)

    
     Flow of decompresssion:
     The variables old_code and new_code holds the (12 bit) codes from the
     compressed file, Char holds a byte and String a variable length of bytes.


                                    (start)
                                       |
                        [input first code into old_code]
                                       |
                        [Output translation of old_code]
    __________________________________>|
    |                                  |
    |                       [Input next code into new_code]
    |                                  |
    |                          [Is new_code in table?]
    |                No _______________|________________  Yes
    |                   |                              |
    |  [String = translation of old_code]     [String = translation of new_code]
    |                   |                              |
    |        [String = string + char]                  |
    |                   |                              |
    |                   |______________________________|
    |                                  |
    |                           [Write string]
    |                                  |
    |                      [Char = first byte in string]
    |                                  |
    |                 [Add entry in table for old_code + char]
    |                                  |
    |                        [old_code = new_code]
    |                                  |
    |                           [More codes to input?]
    |______________ Yes _______________|
                                       | No
                                    (Done)
                                    


3. Implementation -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
    
    The string table consist of 4096 entries (12 bit code, since 2^12 = 4096), 
    where (as mentioned above) the first 256 entries represents the byte values 
    0-255 and the entries 256-4095 represents strings. 
    
    When this table is filled, the program is stucked to use it, 
    (this is where a 'good' program would do soething like dump the table as 
    a huffman tree and start all over again) so this means that a file with 
    a lot of duplicated strings (such as log files) is compressed alot. 
    
    Smaller files, or files with alot of different strings might not be 
    compressed at all. For example, a file that consists of the  ten characters 
    "ABCDEFGHIJ" would be increased by 50% instead of compressed since each 
    character represents 12 bits.

    In order to make the program some what effichant, and disable brutforcing when 
    looking for string entries in the compression flow, i use a 'index table', 
    that exists of 256 integer arrays that holds the indexes of the entries in the 
    code table that ends with the byte of the index in the index array.
    
    If each entry in the strin table would hold the string it represented, it 
    would cost alot of memory, so each entry has a pointer to a entry to add 
    before the byte in the current entry (like a linked list). 
    The string 'ABC', would look something like this:

    String table:
    [0, 1, ... , 'A', ..., 256, 'B', 'C', ... ]
                  |______________|____| End byte
                  |              |     
    	     First byte       Second byte
  
    Index table:
    [0, 1, ..., 'B', 'C', ..., 4095]
                 |    |
               [257] [258]
   
   Well, as i said the intention was to learn assembly. But i thought that an
   explanation of the algorithm would compensate for unreadable code. ;-)
  
