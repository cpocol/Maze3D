;Procedures:
;CastX
;CastY
;Render
;"main"

;Notes:
; - the circle has 1920 degrees
; - each map element has 128x128 units in size
; - if you modify "map.txt", run txt2bin.exe
; - use arrow keys to move arround
;    - use one key at a time
;    - expect a delay after pressing a key

.286

StackSeg segment "stack"
   db 1000 dup(0)
   ssp label word
StackSeg ends

data segment para "data"
   Texture db 16384 dup(0)  ;offset of Texture=0 - important
   VideoAddr dw 0a000h

   ;player's position and direction
   x dw 370
   y dw 400
   direction dw 280
   ;player's speed
   StepLen equ 30
   TurnAng equ 20

   MaxFramesCnt dw 1000

   SkyColor equ 9
   GndColor equ 1

   Ray dw 0    ;current ray on the screen 0..319
   ang dw 0    ;angle of the current ray

   ;wall strike results
   xX dw 0
   xY dw 0
   yX dw 0
   yY dw 0
   HalfHeight    dw 320 dup(0)
   OldHalfHeight dw 320 dup(0)
   Curr_HalfHeight dw 0
   Column db 320 dup(0)

   ;map related
   Map db 4096 dup(0)
   MapWidth db 0
   MapHeight db 0
   MaxWidth dw 0
   MaxHeight dw 0

   ;constants for FPU instructions
   _960 dw 960
   _64 dw 64
   _128 dw 128
   _256 dw 256

   ;FPU related
   temp dq 0
   tempdd dd 0
   part dq 0
   elem dq 0
   h dw 0

   ;LUTs
   Tan dw 1920 dup(0)
   cTan dw 1920 dup(0)
   Sin dw 1920 dup(0)
   Cos dw 1920 dup(0)
   PrecWMulti dw 64 dup(0)
   PrecalcHFactor dw 320 dup(0)
   Precalc8192DivH dw 512 dup(0)
   Precalc6400DivH dw 512 dup(0)
   TanShift equ 7

   mapFile db "map.bin",0
   textureFile db "texture.tga",0
   handle dw 0

   sptemp dw 0 ;used when running out of registers
data ends

include appendix.asm
code segment para public "code"
assume ds:data, cs:code,  ss:StackSeg


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CastX proc  near
      cmp di, 480
      jle smallangle     ; smallangle=-480..480
      cmp di, 1440
      jge smallangle
      shl di, 1
      mov ax, Tan[di]
      mov di, ax          ; di=Tan[ang]
      mov bx, x           ; bx=x
      mov dx, bx
      and dx, 0ff80h      ; x0=x and 0ff80
      dec dx              ; x0--
      mov si, dx          ; si=x0

      sub dx, bx          ; dx=x0-x
      imul dx             ; (x0-x)*Tan
      mov bl, ah
      mov bh, dl
;      shl bx, 1          ; +1bit
      add bx, y           ; bx=y0

      neg di              ; di=dy
      xchg di, bx         ; di=y0, bx=dy
      sar bx, 1
      mov ax, -128        ; si=x0, ax=dx

      jmp search
   smallangle:
      shl di, 1
      mov ax, Tan[di]
      mov di, ax          ; di=Tan[ang]
      mov bx, x           ; bx=x
      mov dx, bx
      and dx, 0ff80h      ; x0=x and 0ff80
      add dx, 128         ; x0=(x and 0ff80)+128
      mov si, dx          ; si=x0

      sub dx, bx          ; dx=x0-x
      imul dx             ; (x0-x)*Tan
      mov bl, ah
      mov bh, dl
;      shl bx, 1          ; +1bit
      add bx, y           ; bx=y0

      xchg bx, di         ; di=y0, bx=dy
      sar bx, 1
      mov ax, 128         ; si=x0, ax=dx

   search:
      cmp di, 0           ; y0<0 ?
      jl endsearch
      cmp di, MaxHeight   ; y0>MaxHight ?
      jg endsearch

      cmp si, 0           ; x0<0 ?
      jl endsearch
      cmp si, MaxWidth    ; x0>MaxWidth ?
      jg endsearch

      mov dx, si
      shr dx, 7           ; x0>>7
      mov bp, di
      shr bp, 7           ; y0>>7*2
      shl bp, 1
      add dx, PrecWMulti[bp]
      mov bp, dx
      cmp Map[bp], 0
      jne endsearch

      add si, ax
      add di, bx
      jmp search
   endsearch:
      mov xX, si
      mov yX, di

      ret
CastX endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CastY proc  near
      cmp di, 960
      jle smallangleY     ; smallangle=0..960
      shl di, 1
      mov ax, cTan[di]
      mov di, ax          ; di=cTan[ang]
      mov bx, y           ; bx=y
      mov dx, bx
      and dx, 0ff80h      ; y0=y and 0ff80
      dec dx              ; y0=(y and 0ff80)-1
      mov si, dx          ; si=y0

      sub dx, bx          ; dx=y0-y
      imul dx             ; (y0-y)*cTan
      mov bl, ah
      mov bh, dl
;      shl bx, 1          ; +1bit
      add bx, x           ; bx=x0

      neg di              ; di=dx
      xchg bx, di         ; di=x0, bx=dx
      sar bx, 1
      mov ax, -128        ; si=y0, ax=dy
      jmp searchY
   smallangleY:
      shl di, 1
      mov ax, cTan[di]
      mov di, ax          ; di=cTan[ang]
      mov bx, y           ; bx=y
      mov dx, bx
      and dx, 0ff80h      ; y0=y and 0ff80
      add dx, 128         ; y0+=128
      mov si, dx          ; si=y0

      sub dx, bx          ; dx=y0-y
      imul dx             ; (y0-y)*cTan
      mov bl, ah
      mov bh, dl
;      shl bx, 1          ; +1bit
      add bx, x           ; bx=x0

;      neg di             ; di=dx
      xchg di, bx         ; di=x0, bx=dx
      sar bx, 1
      mov ax, 128         ; si=y0, ax=dy

   searchY:
      cmp si, 0           ; y0<0 ?
      jl endsearchY
      cmp si, MaxHeight   ; y0>MaxHight ?
      jg endsearchY

      cmp di, 0           ; x0<0 ?
      jl endsearchY
      cmp di, MaxWidth    ; x0>MaxWidth ?
      jg endsearchY

      mov dx, di
      shr dx, 7           ; x0>>7
      mov bp, si
      shr bp, 7           ; y0>>7*2
      shl bp, 1
      add dx, PrecWMulti[bp]
      mov bp, dx
      cmp Map[bp], 0
      jne endsearchY

      add si, ax
      add di, bx
      jmp searchY
   endsearchY:
      mov xY, di
      mov yY, si
      ret
CastY endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
Render Proc  near
      finit
      mov Ray, 0
   forRay:
;     OldHalfHeight[Ray] = HalfHeight[Ray];
      mov bx, Ray
      shl bx, 1

      mov ax, HalfHeight[bx]
      mov OldHalfHeight[bx], ax

      EVEN
      mov di, 2080
      add di, direction   ; ang=160+direction-i+1920
      sub di, Ray
      cmp di, 1920
      jb good
      sub di, 1920        ; ang=ang%1920
      cmp di, 1920
      jb good
      sub di, 1920        ; ang=ang%1920
   good:
      mov ang, di
      call CastX
      mov di, ang
      call CastY
      mov ax, x
      mov bx, ax
      sub ax, xX          ; ax=x-xX
      jns pozitive1
      neg ax              ; ax=abs(ax)
   pozitive1:
      sub bx, xY          ; bx=x-xY
      jns pozitive2
      neg bx              ; bx=abs(bx)
   pozitive2:
      cmp ax, bx          ; abs(x-xX)<abs(x-xY)       ?
      jge ChooseY
      mov ax, xX
      mov bx, yX
      mov dl, bl          ; colunm=yX mod 128
      jmp _endif
   ChooseY:
      mov ax, xY
      mov bx, yY
      mov dl, al          ; colunm=xY mod 128
   _endif:
      and dl, 7Fh         ; column=x (or y) mod 128
      mov bp, Ray
      mov Column[bp], dl

      ;;;;;;;;;;; calculate height ;;;;;;;;;;;;;;;;;
      sub ax, x           ; (x-xStruck)^2
      imul ax
      mov di, dx
      mov si, ax

      sub bx, y           ; (y-yStruck)^2
      mov ax, bx
      imul bx

      add si, ax          ; (x-xStruck)^2+(y-yStruck)^2
      adc di, dx

      mov bx, Ray
      shl bx, 1
      fild PrecalcHFactor[bx]

      mov word ptr tempdd, si
      mov word ptr tempdd+2, di
      fild tempdd
      fsqrt
      fdivp st(1), st     ; /
      fistp h             ; h=PrecalcHFactor[bx]/sqrt(DX^2+DY^2)
      mov di, h

      ; saturate
      cmp di, 511
      jbe HOk
      mov di, 511
   HOk:

      mov HalfHeight[bx], di

      call ClrRay

      inc Ray
      cmp Ray, 320
      jge endforRay
      jmp forRay
   endforRay:

      ;;;;;;;;; draw the walls ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
      xor cx, cx
   nexti:
      mov bx, cx
      shl bx, 1
      mov bp, cx

      mov di, HalfHeight[bx]
      shl di, 1

      ; first, prepare texture addesses
      xor dh, dh
      mov dl, Column[bp]

      shl dx, 7           ; Adr0=col*128
      mov bp, dx          ; TextureAddr0=bp

      mov bx,Precalc8192DivH[di]  ;bx=Dh=8192/h

      push cx
      cli
      mov sptemp, sp

      cmp di, 200
      jle small_h         ; h>100 => Adr0=col*128+64-6400/h
      add bp, Precalc6400DivH[di]    ; Adr0=col*128+64-6400/h
      xor dx, dx          ; j=0      ; j=dx=up
      mov sp, 200         ; sp=down=200
      jmp go2for
   small_h:
      mov sp, di
      shr sp, 1
      mov dx, 100
      sub dx, sp          ; dx=up=j=100-h/2
      add sp, 100         ; sp=down=100+h/2
   go2for:

      mov di, cx
      mov cx, dx
      mov ax, dx
      shl cx, 8
      shl ax, 6
      add cx, ax
      add di, cx
      xor cx, cx          ; cx=hx=0
      mov es, VideoAddr
      mov ax, data
      mov ds, ax
   nextj:
      mov si, bp
      mov ax, cx
      shr ax, 7
      add si, ax          ; TextureAddr=TextureAddr0+(hx>>7)
      add cx, bx          ; hx+=Dh
      movsb               ; si=si+1; di=di+1
      add di, 319
      inc dx
      cmp dx, sp
      jnz nextj

      mov sp, sptemp
      sti
      pop cx
      inc cx
      cmp cx, 320
      je endfori          ; artifice for long jump
      jmp nexti
   endfori:
      ret
Render endp

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
start:
      mov ax, StackSeg
      mov ss, ax
      mov sp, ssp
      mov ax, data
      mov ds, ax

      InitGraph 13h
      call ReadData
      call InitLUTs

   _while:
      ;Delay 100
      call Render
      call TreatKeyboard
      ;dec MaxFramesCnt ;uncomment to limit the frames to be rendered
      cmp MaxFramesCnt, 0
      jne _while

      call ShutDown
code ends
end start
