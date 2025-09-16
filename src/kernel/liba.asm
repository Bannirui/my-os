BITS 16
[global printPos]

printPos:
    pusha
    mov SI, SP            	;use SI
    add SI, 16 + 2        	;First parameter address
    mov AX, CS
    mov DS, AX
    mov BP, [SI]          	;BP = offset
    mov AX, DS            	;
    mov ES, AX            	;ES = DS
    mov CX, [SI + 2]      	;CX = String length
    mov AX, 1301H         	;functon number AH = 13 AL = 01H,Indicates that the cursor displays the end of the string
    mov BX, 0007H         	;BH = page number BL = 07 black and white
    mov DH, [SI + 4]      	;Line number= 0
    mov DL, [SI + 6]     	;Column number = 0
    int 10H               	;BIOS 10H interrupt call
    popa
    retf