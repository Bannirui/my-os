; liba.asm
[BITS 16]
global printPos

; void printPos(char* msg, uint16_t len, uint16_t row, uint16_t col);
printPos:
    pusha                ; 保存 AX,BX,CX,DX,SI,DI,BP,SP (共16字节)
    mov si, sp
    ; 16 = pusha pushed bytes
    ; 2  = return IP pushed by CALL (near call)
    add si, 16 + 2       ; si -> first parameter (msg offset)
    ; 参数布局 (all 16-bit):
    ; [si]   -> msg (offset)
    ; [si+2] -> len (word)
    ; [si+4] -> row (word)
    ; [si+6] -> col (word)

    mov bp, [si]         ; bp = offset of msg
    mov cx, [si + 2]     ; cx = len
    mov dh, [si + 4]     ; dx = row (word)
    mov dl, [si + 6]     ; bx = col (word)

    ; 设置 ES = DS（假设 C 数据位于数据段，DS 已被设置正确）
    mov ax, ds
    mov es, ax

    ; BIOS write string AH=13h AL=01h uses ES:BP, CX etc (your previous code used AH=13 AL=01)
    mov ax, 0x1301
    ; page and attribute in BX: we put attribute low byte
    ; you already have bx = col, will overwrite low word - so set attribute in BH maybe:
    mov bh, 0x00         ; page number / high byte if needed
    mov bl, 0x07         ; attribute (white on black)
    ; set BP to point to string (BP currently used as pointer)
    ; but BP is currently holding msg offset (we used BP as temp) - that's ok since we saved BP on pusha
    ; For BIOS call we need ES:BP pointing to string:
    mov bp, bp           ; (no-op, BP already msg offset)
    int 0x10

    popa
    ret ; 弹出栈ip 跳到段内ip偏移上 也就是调用的地方
