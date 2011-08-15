nop
hlt
db 41h
dw 6477h
dd 44444444h
sahf
lahf
clc
cld
cli
stc
std
sti
cmpsb
cmpsw
cmpsd
lodsb
lodsw
lodsd
movsb
movsw
movsd
scasb
scasw
scasd
stosb
stosw
stosd
rep
repz
repe
repnz
repne
loop 4
loopz 4
loopnz 4
loope 4
loopne 4
push edx
pop ecx
pusha
pushad
popa
popad
pushf
pushfd
popf
popfd
aaa
aas
aam
aad
daa
das
cbw
cdq
cwd
cwde
call ebx
ret
retn
retf
int 80h
into
iret
iretd
enter 2, 4
leave
not edi
neg esi
and ebx, ecx
or ecx, edx
xor eax, eax
rol ebx, 2
ror ebx, 2
rcl ebx, 2
rcr ebx, 2
shl ebx, 2
shr ebx, 2
sal ebx, 2
sar ebx, 2
mov esp, ebx
xchg ebp, eax
in eax, 25h
out 25h, eax
add eax, ebx
sub eax, ebx
adc eax, ebx
sbb eax, ebx
mul ecx
div edx
imul dx
idiv cx
inc ecx
dec edx
cmp eax, ebx
test bx, cx
jmp edx
jcxz 25h
jz 1234h
jnz 1234h
jc 1234h
jnc 1234h
jo 1234h
jno 1234h
jp 1234h
jnp 1234h
jpe 1234h
jpo 1234h
js 1234h
jns 1234h
je 1234h
jne 1234h
ja 1234h
jna 1234h
jae 1234h
jnae 1234h
jb 1234h
jnb 1234h
jbe 1234h
jnbe 1234h
jg 1234h
jng 1234h
jge 1234h
jnge 1234h
jl 1234h
jnl 1234h
jle 1234h
jnle 1234h
cmc
lock
wait
xlat
