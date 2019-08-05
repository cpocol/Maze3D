;Macros:
;InitGraph Mode
;ReadKeyNoWait   =>   ah=scancode, al=ascii, ZF=1 if read
;setrgb color, red, green, blue
;Delay ms

;Procedures:
;ReadData
;InitLUTs
;ShutDown
;GoForwardProc
;GoBackwardProc
;TreatKeyboard
;ClrRay

InitGraph macro Mode
      mov ax, Mode
      int 10h
endm

ReadKeyNoWait macro
      mov ah, 1
      int 16h
endm

setrgb macro color, red, green, blue
      mov  dx, 3C8h
      mov  al, color
      out  dx, al
      inc  dx
      mov  al, red
      out  dx, al
      mov  al, green
      out  dx, al
      mov  al, blue
      out  dx, al
endm

Delay macro ms
     push ax
     push bx
     push cx
     push dx
     mov ax, 1000
     mov bx, ms
     mul bx
     mov cx, dx
     mov dx, ax
     mov ah, 86h
     int 15h
     pop dx
     pop cx
     pop bx
     pop ax
endm


code segment para public "code"
assume cs:code, ds:data

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ReadData Proc near
      ;;;;;;;;;;;;;;; read map ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      mov ah, 3dh     ; open mapfile
      mov al, 0       ; read-only mode
      mov dx, offset mapFile
      int 21h
      mov handle, ax

      mov ah, 3fh     ; read height
      mov bx, handle
      mov cx, 1       ; char by char
      mov dx, offset MapHeight
      int 21h
      mov ah, 0
      mov al, MapHeight
      shl ax, 7
      mov MaxHeight, ax

      mov ah, 3fh     ; read width
      mov bx, handle
      mov cx, 1       ; char by char
      mov dx, offset MapWidth
      int 21h
      mov ah, 0
      mov al, MapWidth
      shl ax, 7
      mov MaxWidth, ax

      mov al, MapWidth
      mul MapHeight
      mov cx, ax      ; high*width elements
      mov ah, 3fh     ; read map
      mov bx, handle
      mov dx, offset Map
      int 21h

      mov ah, 3eh      ; close mapfile
      mov bx, handle
      int 21h

      ;;;;;;;;;;;;;;; read Texture ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      mov ah, 3dh     ; open texture file
      mov al, 0       ; read-only mode
      mov dx, offset TextureFile
      int 21h
      mov handle, ax

      ;;;;;;;;;;;;;;; read Header
      mov di, 0
   ReadNextByte:
      mov ah, 3fh     ; read byte from file
      mov bx, handle
      mov cx, 1       ; char by char
      mov dx, offset Texture  ; writing anywhere
      int 21h

      inc di
      cmp di, 18
      jne ReadNextByte

      ;;;;;;;;;;; read Pallete
      mov ah, 3fh       ; read byte from file
      mov bx, handle
      mov cx, 768       ; 3*256
      mov dx, offset Texture  ; writing anywhere
      int 21h

      mov di, 0
   TreatNextColor:
      mov ax, di
      mov Texture[1000], al
      shl ax, 1
      add ax, di       ; di*3
      mov si, ax
      mov bx, si       ; bx=di*3
      shr Texture[si], 2
      inc si
      mov bp, si       ; bp=di*3+1
      shr Texture[si], 2
      inc si           ; si=di*3+2
      shr Texture[si], 2
      setrgb  Texture[1000], Texture[si], Texture[bp], Texture[bx]

      inc di
      cmp di, 256
      jne TreatNextColor

      ;;;;;;;;;; read Texture pixels
      mov ah, 3fh             ; read byte from file
      mov bx, handle
      mov cx, 128*128         ; char by char
      mov dx, offset Texture  ; writing anywhere
      int 21h

      mov si, 0
   fori_:
      mov di, 0
   forj_:
      mov bx, di
      shl bx, 7
      add bx, si
      mov al, Texture[bx]
      mov bp, si
      shl bp, 7
      add bp, di
      mov ah, Texture[bp]
      mov Texture[bp], al
      mov Texture[bx], ah
      inc di
      cmp di, si
      jnge forj_

      inc si
      cmp si, 128
      jne fori_

      mov si, 0
   fori__:
      mov di, 0
   forj__:
      mov bx, si
      shl bx, 7
      add bx, di
      mov al, Texture[bx]
      mov bp, 127
      sub bp, si
      shl bp, 7
      add bp, di
      mov ah, Texture[bp]
      mov Texture[bp], al
      mov Texture[bx], ah
      inc di
      cmp di, 128
      jnge forj__

      inc si
      cmp si, 64
      jne fori__

      mov si, 0
   fori___:
      mov di, 0
   forj___:
      mov bx, si
      shl bx, 7
      add bx, di
      mov al, Texture[bx]
      mov bp, si
      shl bp, 7
      add bp, 128
      sub bp, di
      mov ah, Texture[bp]
      mov Texture[bp], al
      mov Texture[bx], ah
      inc di
      cmp di, 64
      jnge forj___

      inc si
      cmp si, 128
      jne fori___

      mov ah, 3eh      ; close TextureFile
      mov bx, handle
      int 21h
      ret
ReadData endp


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
InitLUTs Proc near
      ;;;;;;;;;;;;;;; precompute ;;;;;;;;;;;;;;;;;;;;;;;;;;
      finit
      mov Tan[0], 0
      mov cTan[0], 16000
      mov Sin[0], 0
      mov Cos[0], 128

      mov di, 2
      fild _960
      fldpi
      fdivrp st(1), st
      fstp elem              ; pi/960
   next1:
      fld part
      fadd elem
      fst part
      fptan
      ffree st
      fincstp
      fld st
      fmul st, st(1)
      fld1
      fadd st(1), st
      ffree st
      fincstp
      fsqrt
      fld1
      fdivr
      fst temp
      fmul st, st(1)
      fimul _128
      fistp Sin[di]
      fld temp
      fimul _128
      fistp Cos[di]

      fst temp
      fld1
      fdivr
      fimul _256
      fistp cTan[di]

      fld temp
      fimul _256
      fistp Tan[di]
      cmp di, 2*480
      jl  _next
      cmp di, 2*1440
      jle lb3
      jmp _next
   lb3:
      neg Sin[di]
      neg Cos[di]
   _next:
      inc di
      inc di
      cmp di, 2*1920
      jne next1      ; rellative jump >128

      mov Tan[2*478], 16000*2
      mov Tan[2*479], 16000*2
      mov Tan[2*480], 16000*2
      mov Tan[2*1439], 16000*2
      mov Tan[2*1440], 16000*2
      mov Tan[2*481], -16000*2
      mov Tan[2*482], -16000*2
      mov Tan[2*1441], -16000*2
      mov Tan[2*1442], -16000*2
      mov Tan[2*1442], -16000*2

      mov cTan[2*0], 16000*2
      mov cTan[2*1], 16000*2
      mov cTan[2*2], 16000*2
      mov cTan[2*960], 16000*2
      mov cTan[2*961], 16000*2
      mov cTan[2*962], 16000*2
      mov cTan[2*959], -16000*2
      mov cTan[2*1919], -16000*2

      ;;;;;;;;;;;;; precalc Width*0..High ;;;;;;;;;;;;;;
      mov cx, 0
   forind:
      mov bx, cx
      shl bx, 1
      mov al, cl
      mul MapWidth
      mov PrecWMulti[bx], ax
      inc cx
      cmp cl, MapHeight
      jne forind

      ;;;;;;;;;;;;; precalc PrecalcHFactor ;;;;;;;;;;;;;;
      mov cx, 0
   fori1_:
      mov ax, cx            ; (160-i)^2
      sub ax, 160
      imul ax

      add ax, 0FFFFh        ; (160-i)^2+65535
      adc dx, 0

      mov word ptr tempdd, ax
      mov word ptr tempdd+2, dx
      fild tempdd

      fsqrt                 ; sqrt
      fimul _64             ;*128/2 (instead of doing h/2)

      mov bx, cx
      shl bx, 1
      fistp PrecalcHFactor[bx]

      inc cx
      cmp cx, 320
      jne fori1_

      mov cx, 1
   fori2:
      xor dx, dx
      mov ax, 8192
      div cx
      mov bx, cx
      shl bx, 1
      mov Precalc8192DivH[bx], ax
      inc cx
      cmp cx, 512
      jne fori2

      mov cx, 1
   fori3:
      xor dx, dx
      mov ax, 6400
      div cx
      neg ax
      add ax, 64
      mov bx, cx
      shl bx, 1
      mov Precalc6400DivH[bx], ax
      inc cx
      cmp cx, 512
      jne fori3

;//precalc Precalc6400DivH[h]; 64-Precalc6400DivH[h] !!!
;   for(i=1;i<512;i++)
;      Precalc6400DivH[i]=64-6400/i;

      ;;;;;;;; set intital values
      mov cx, 0
   loopRay:
      mov bx, cx
      shl bx, 1
      mov HalfHeight[bx], 100
      inc cx
      cmp cx, 320
      jne loopRay
      ret
InitLUTs endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ShutDown Proc  near
      InitGraph 3h
      mov ax, 4c00h
      int 21h   ; exit to dos
ShutDown endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GoForwardProc proc  near
      mov di, direction
      shl di, 1
      mov ax, Cos[di]
      mov dx, StepLen
      imul dx
      sar ax, TanShift
      add x, ax
      mov ax, Sin[di]
      mov dx, StepLen
      imul dx
      sar ax, TanShift
      add y, ax
      ret
GoForwardProc endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GoBackwardProc proc  near
      mov di, direction
      shl di, 1
      mov ax, Cos[di]
      mov dx, StepLen
      imul dx
      sar ax, TanShift
      sub x, ax
      mov ax, Sin[di]
      mov dx, StepLen
      imul dx
      sar ax, TanShift
      sub y, ax
      ret
GoBackwardProc endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TreatKeyboard proc  near
; automatic movement starts here
      ;add direction, 1   ;uncomment for automatic movement
      cmp direction, 1920
      jl  Labelu
      sub direction, 1920
   Labelu:
; automatic movement ends here
      ReadKeyNoWait
      jz EndTreat
      push ds
      mov bx, 40h
      mov ds, bx
      mov si, 1ch
      mov bx, [si]
      mov si, 1ah
      mov [si], bx  ;acknowledge that we got the key
      pop ds
      cmp al, 0
      je TreatExtendedCode
      cmp al, 27
      je gameover
      jmp EndTreat
   TreatExtendedCode:
      cmp ah, 72
      je goforward
      cmp ah, 80
      je gobackward
      cmp ah, 75
      je turnleft
      cmp ah, 77
      je turnright
      jmp EndTreat
   goforward:
      call GoForwardProc
      jmp EndTreat
   gobackward:
      call GoBackwardProc
      jmp EndTreat
   turnleft:
      add direction, TurnAng
      cmp direction, 1920
      jl  EndTreat
      sub direction, 1920
      jmp EndTreat
   turnright:
      sub direction, TurnAng
      cmp direction, 0
      jge EndTreat
      add direction, 1920
      jmp EndTreat
   gameover:
      call ShutDown
   EndTreat:
      ret
TreatKeyboard endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ClrRay proc
      mov bx, Ray
      shl bx, 1
      inc OldHalfHeight[bx] ; seems it needs to erase one more pixel

      mov ax, HalfHeight[bx]
      mov Curr_HalfHeight, ax

      ;saturate them
      cmp OldHalfHeight[bx], 100
      jle OldHalfHeight_OK
      mov OldHalfHeight[bx], 100
OldHalfHeight_OK:

      cmp Curr_HalfHeight, 100
      jle Curr_HalfHeight_OK
      mov Curr_HalfHeight, 100
Curr_HalfHeight_OK:


;   for(int i = 100 - Old_HalfHeight; i < 100 - Curr_HalfHeight; i++)
      mov ax, VideoAddr
      mov es, ax
      mov si, 100
      sub si, OldHalfHeight[bx]         ; 100 - Old_HalfHeight    =>    si

      mov ax, si
      mov dx, ax
      shl ax, 8
      shl dx, 6
      add ax, dx
      add ax, Ray
      mov di, ax
      mov al, SkyColor          ; sky color
      push ds
      mov dx, 100
      sub dx, Curr_HalfHeight    ; 100 - Curr_HalfHeight      =>   dx
   loopup:
      mov cx, 1
      mov bx, di
      stosb
      mov di, bx
      add di, 320
      inc si
      cmp si, dx
      jl loopup
      pop ds

;   for (i = 100 + Curr_HalfHeight; i <= 100 + Old_HalfHeight; i++)
      mov bx, Ray
      shl bx, 1
      mov si, 100
      add si, Curr_HalfHeight        ; 100 + Curr_HalfHeight    =>    si

      mov ax, si
      mov dx, ax
      shl ax, 8
      shl dx, 6
      add ax, dx
      add ax, Ray
      mov di, ax
      mov al, GndColor
      push ds
      mov dx, 100

      add dx, OldHalfHeight[bx]    ; 100 + Old_HalfHeight      =>   dx
   loopdown:
      mov cx, 1
      mov bx, di
      stosb
      mov di, bx
      add di, 320
      inc si
      cmp si, dx
      jl loopdown
      pop ds

      ret
ClrRay endp

code ends