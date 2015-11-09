/*
 *  Multiply two 4096-bit numbers using AVX512F instructions
 *
 *  Copyright (C) 2015  Vlad Krasnov
 *  Copyright (C) 2015  Shay Gueron
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 */

.align 64
# Masks to convert 2^64->2^28
permMask:
.short 0, 1, 0, 0,  1, 2, 3, 0,  3, 4, 5, 0,  5, 6, 0, 0
.short 7, 8, 0, 0,  8, 9,10, 0, 10,11,12, 0, 12,13, 0, 0
shiftMask:
.quad  0,12, 8, 4, 0,12, 8, 4

# Masks to convert 2^28->2^64
.align 64
fixMask0:
.long  0, 1, 4, 1, 8, 1,12, 1
.long 18, 1,22, 1,26, 1, 1, 1
fixMask1:
.short  4, 5, 3, 3
.short 12,13, 3, 3
.short 20,21, 3, 3
.short 28,29, 3,36
.short 40,41, 3, 3
.short 48,49, 3, 3
.short 56,57, 3, 3
.short  3, 3, 3, 3
fixMask2:
.long  4, 1, 8, 1,12, 1,16, 1,22, 1,26, 1,30, 1, 1, 1
fixShift0:
.quad  0, 8,16,24, 4,12,20,28
fixShift1:
.quad 28,20,12, 4,24,16, 8,64
fixShift2:
.quad 56,48,40,32,52,44,36,30

# Mask for the bottom 28 bits
andMask:
.quad 0xFFFFFFF
# The constant 1
one:
.quad 1

# We don't have enought registers to keep the entire result :(
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
.set ACC\i, %zmm\i
.endr
# Helper registers
.set ZERO, %zmm19     # zero
.set AND_MASK, %zmm20 # for masking the 28 bits of each qword
.set M_ONE, %zmm21    # for -1
.set H0, %zmm22
.set H1, %zmm23
.set H2, %zmm24
.set H3, %zmm25
.set H4, %zmm26
# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %r10
.set r_ptr, %r11
.set a_ptr, %rsi
.set b_ptr, %rdx

.macro IFMA src1,src2,dst
    vpmuludq \src1, \src2, H1
    vpaddq H1, \dst, \dst
.endm

# void mul4096_avx512(uint64_t res[64], uint64_t a[32], uint64_t b[32]);
.globl mul4096_avx512
.type mul4096_avx512, @function
mul4096_avx512:

    push %rbp
    mov %rsp, %rbp
    sub $(64*(37+19+19+2)), %rsp
    and $-64, %rsp

    mov   $0xf, %ecx
    kmovd %ecx, %k1

    vpbroadcastq andMask(%rip), AND_MASK
    vpxorq ZERO, ZERO, ZERO
    # First we need to convert the input A from radix 2^64 to redundant 2^28
    vmovdqa64 permMask(%rip), H0
    vmovdqa64 shiftMask(%rip), H1
    # Load values with 28-byte intervals and shuffle + shift accordingly
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vpermw 28*\i(a), H0, ACC\i
.endr
    vmovdqu16 28*18(a), ACC18{%k1}{z}
    vpermw ACC18, H0, ACC18
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vpsrlvq H1, ACC\i, ACC\i
    vpandq AND_MASK, ACC\i, ACC\i
    vmovdqa64 ACC\i, 64*\i(%rsp)
.endr
    lea (%rsp), a_ptr
    lea 64*19(%rsp), %rsp

    # Convert B
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vpermw 28*\i(b), H0, ACC\i
.endr
    vmovdqu16 28*18(b), ACC18{%k1}{z}
    vpermw ACC18, H0, ACC18
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vpsrlvq H1, ACC\i, ACC\i
    vpandq AND_MASK, ACC\i, ACC\i
    vmovdqa64 ACC\i, 64*\i(%rsp)
.endr
    lea (%rsp), b_ptr
    lea 64*19(%rsp), r_ptr

    vpbroadcastq 0*64(b_ptr), H0
    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vpmuludq 64*(\ii)(a_ptr), H0, ACC\ii
    .endr
    vmovdqa64 ACC0, 64*0(r_ptr)

    vpbroadcastq 1*64(b_ptr), H0
    .irp ii, 1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    IFMA 64*(\ii-1)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC0
    vmovdqa64 ACC1, 64*1(r_ptr)

    vpbroadcastq 2*64(b_ptr), H0
    .irp ii, 2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0
    IFMA 64*((\ii+17)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC1
    vmovdqa64 ACC2, 64*2(r_ptr)

    vpbroadcastq 3*64(b_ptr), H0
    .irp ii, 3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1
    IFMA 64*((\ii+16)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC2
    vmovdqa64 ACC3, 64*3(r_ptr)

    vpbroadcastq 4*64(b_ptr), H0
    .irp ii, 4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2
    IFMA 64*((\ii+15)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC3
    vmovdqa64 ACC4, 64*4(r_ptr)

    vpbroadcastq 5*64(b_ptr), H0
    .irp ii, 5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3
    IFMA 64*((\ii+14)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC4
    vmovdqa64 ACC5, 64*5(r_ptr)

    vpbroadcastq 6*64(b_ptr), H0
    .irp ii, 6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4
    IFMA 64*((\ii+13)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC5
    vmovdqa64 ACC6, 64*6(r_ptr)

    vpbroadcastq 7*64(b_ptr), H0
    .irp ii, 7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5
    IFMA 64*((\ii+12)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC6
    vmovdqa64 ACC7, 64*7(r_ptr)

    vpbroadcastq 8*64(b_ptr), H0
    .irp ii, 8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6
    IFMA 64*((\ii+11)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC7
    vmovdqa64 ACC8, 64*8(r_ptr)

    vpbroadcastq 9*64(b_ptr), H0
    .irp ii, 9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7
    IFMA 64*((\ii+10)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC8
    vmovdqa64 ACC9, 64*9(r_ptr)

    vpbroadcastq 10*64(b_ptr), H0
    .irp ii, 10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8
    IFMA 64*((\ii+9)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC9
    vmovdqa64 ACC10, 64*10(r_ptr)

    vpbroadcastq 11*64(b_ptr), H0
    .irp ii, 11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9
    IFMA 64*((\ii+8)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC10
    vmovdqa64 ACC11, 64*11(r_ptr)

    vpbroadcastq 12*64(b_ptr), H0
    .irp ii, 12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10
    IFMA 64*((\ii+7)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC11
    vmovdqa64 ACC12, 64*12(r_ptr)

    vpbroadcastq 13*64(b_ptr), H0
    .irp ii, 13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11
    IFMA 64*((\ii+6)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC12
    vmovdqa64 ACC13, 64*13(r_ptr)

    vpbroadcastq 14*64(b_ptr), H0
    .irp ii, 14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12
    IFMA 64*((\ii+5)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC13
    vmovdqa64 ACC14, 64*14(r_ptr)

    vpbroadcastq 15*64(b_ptr), H0
    .irp ii, 15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    IFMA 64*((\ii+4)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC14
    vmovdqa64 ACC15, 64*15(r_ptr)

    vpbroadcastq 16*64(b_ptr), H0
    .irp ii, 16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
    IFMA 64*((\ii+3)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC15
    vmovdqa64 ACC16, 64*16(r_ptr)

    vpbroadcastq 17*64(b_ptr), H0
    .irp ii, 17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    IFMA 64*((\ii+2)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC16
    vmovdqa64 ACC17, 64*17(r_ptr)

    vpbroadcastq 18*64(b_ptr), H0
    .irp ii, 18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
    IFMA 64*((\ii+1)%19)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*18(a_ptr), H0, ACC17
    vmovdqa64 ACC18, 64*18(r_ptr)

    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vmovdqa64 ACC\ii, 64*(\ii+19)(r_ptr)
    .endr
    vmovdqa64 ZERO, 64*37(r_ptr)

    add $8, b_ptr
    add $8, r_ptr

    mov $7, itr1
1:

    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vmovdqu64 64*\ii(r_ptr), ACC\ii
    .endr

    vpbroadcastq 0*64(b_ptr), H0
    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    IFMA 64*((\ii+19)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC0, 0*64(r_ptr)
    vmovdqu64 19*64(r_ptr), ACC0

    vpbroadcastq 1*64(b_ptr), H0
    .irp ii,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0
    IFMA 64*((\ii+18)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC1, 1*64(r_ptr)
    vmovdqu64 20*64(r_ptr), ACC1

    vpbroadcastq 2*64(b_ptr), H0
    .irp ii,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1
    IFMA 64*((\ii+17)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC2, 2*64(r_ptr)
    vmovdqu64 21*64(r_ptr), ACC2

    vpbroadcastq 3*64(b_ptr), H0
    .irp ii,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2
    IFMA 64*((\ii+16)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC3, 3*64(r_ptr)
    vmovdqu64 22*64(r_ptr), ACC3

    vpbroadcastq 4*64(b_ptr), H0
    .irp ii,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3
    IFMA 64*((\ii+15)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC4, 4*64(r_ptr)
    vmovdqu64 23*64(r_ptr), ACC4

    vpbroadcastq 5*64(b_ptr), H0
    .irp ii,5,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4
    IFMA 64*((\ii+14)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC5, 5*64(r_ptr)
    vmovdqu64 24*64(r_ptr), ACC5

    vpbroadcastq 6*64(b_ptr), H0
    .irp ii,6,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5
    IFMA 64*((\ii+13)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC6, 6*64(r_ptr)
    vmovdqu64 25*64(r_ptr), ACC6

    vpbroadcastq 7*64(b_ptr), H0
    .irp ii,7,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6
    IFMA 64*((\ii+12)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC7, 7*64(r_ptr)
    vmovdqu64 26*64(r_ptr), ACC7

    vpbroadcastq 8*64(b_ptr), H0
    .irp ii,8,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7
    IFMA 64*((\ii+11)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC8, 8*64(r_ptr)
    vmovdqu64 27*64(r_ptr), ACC8

    vpbroadcastq 9*64(b_ptr), H0
    .irp ii,9,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8
    IFMA 64*((\ii+10)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC9, 9*64(r_ptr)
    vmovdqu64 28*64(r_ptr), ACC9

    vpbroadcastq 10*64(b_ptr), H0
    .irp ii,10,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9
    IFMA 64*((\ii+9)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC10, 10*64(r_ptr)
    vmovdqu64 29*64(r_ptr), ACC10

    vpbroadcastq 11*64(b_ptr), H0
    .irp ii,11,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10
    IFMA 64*((\ii+8)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC11, 11*64(r_ptr)
    vmovdqu64 30*64(r_ptr), ACC11

    vpbroadcastq 12*64(b_ptr), H0
    .irp ii,12,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11
    IFMA 64*((\ii+7)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC12, 12*64(r_ptr)
    vmovdqu64 31*64(r_ptr), ACC12

    vpbroadcastq 13*64(b_ptr), H0
    .irp ii,13,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12
    IFMA 64*((\ii+6)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC13, 13*64(r_ptr)
    vmovdqu64 32*64(r_ptr), ACC13

    vpbroadcastq 14*64(b_ptr), H0
    .irp ii,14,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    IFMA 64*((\ii+5)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC14, 14*64(r_ptr)
    vmovdqu64 33*64(r_ptr), ACC14

    vpbroadcastq 15*64(b_ptr), H0
    .irp ii,15,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
    IFMA 64*((\ii+4)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC15, 15*64(r_ptr)
    vmovdqu64 34*64(r_ptr), ACC15

    vpbroadcastq 16*64(b_ptr), H0
    .irp ii,16,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    IFMA 64*((\ii+3)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC16, 16*64(r_ptr)
    vmovdqu64 35*64(r_ptr), ACC16

    vpbroadcastq 17*64(b_ptr), H0
    .irp ii,17,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
    IFMA 64*((\ii+2)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC17, 17*64(r_ptr)
    vmovdqu64 36*64(r_ptr), ACC17

    vpbroadcastq 18*64(b_ptr), H0
    .irp ii,18,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    IFMA 64*((\ii+1)%19)(a_ptr), H0, ACC\ii
    .endr
    vmovdqu64 ACC18, 18*64(r_ptr)

    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vmovdqu64 ACC\ii, 64*(\ii+19)(r_ptr)
    .endr

    add $8, b_ptr
    add $8, r_ptr

    dec itr1
    jnz 1b

    sub $64, r_ptr

    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vmovdqu64 64*\ii(r_ptr), ACC\ii
    .endr
    vpxorq H3, H3, H3
    mov $2, itr1
1:
    vpsrlq $28, ACC0, H0
    vpandq AND_MASK, ACC0, ACC0
    valignq $7, ZERO, H0, H1
    vpaddq H1, ACC0, ACC0

    .irp i,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    vpsrlq $28, ACC\i, H1
    vpandq AND_MASK, ACC\i, ACC\i
    valignq $7, H0, H1, H0
    vpaddq H0, ACC\i, ACC\i
    vmovdqa64 H1, H0
    .endr
    vpaddq H0, H3, H3
    dec itr1
    jnz 1b

    mov $0x8000, %eax
    kmovd %eax, %k1
    vpsubq one(%rip){1to8}, ZERO, M_ONE

    vmovdqa64 fixMask2(%rip), H2
    mov $7, %ecx
    xor %edx, %edx

.macro fix2 ACC0, ACC1
    vmovdqa64 fixMask0(%rip), H0
    vmovdqa64 fixMask1(%rip), H1
    vpermi2d \ACC1, \ACC0, H0
    vpermi2w \ACC1, \ACC0, H1
    vpermt2d \ACC1, H2, \ACC0
    vpsrlvq fixShift0(%rip), H0, H0
    vpsllvq fixShift1(%rip), H1, H1
    vpsllvq fixShift2(%rip), \ACC0, \ACC0
    vpsllw $8, H1, H1{%k1}
    vpaddq H1, H0, H0
    vpaddq H0, \ACC0, \ACC0
    vpcmpuq $1, H0, \ACC0, %k3
    vpcmpuq $0, M_ONE, \ACC0, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq M_ONE, \ACC0, \ACC0{%k3}
.endm

    fix2 ACC0, ACC1
    valignq $7, ACC0, ACC0, ACC0
    fix2 ACC2, ACC3
    valignq $1, ACC0, ACC2, ACC0
    valignq $7, ACC2, ACC2, ACC2
    vmovdqu64 ACC0, 64*0(res)

    fix2 ACC4, ACC5
    valignq $2, ACC2, ACC4, ACC2
    valignq $7, ACC4, ACC4, ACC4
    vmovdqu64 ACC2, 64*1(res)

    fix2 ACC6, ACC7
    valignq $3, ACC4, ACC6, ACC4
    valignq $7, ACC6, ACC6, ACC6
    vmovdqu64 ACC4, 64*2(res)

    fix2 ACC8, ACC9
    valignq $4, ACC6, ACC8, ACC6
    valignq $7, ACC8, ACC8, ACC8
    vmovdqu64 ACC6, 64*3(res)

    fix2 ACC10, ACC11
    valignq $5, ACC8, ACC10, ACC8
    valignq $7, ACC10, ACC10, ACC10
    vmovdqu64 ACC8, 64*4(res)

    fix2 ACC12, ACC13
    valignq $6, ACC10, ACC12, ACC10
    valignq $7, ACC12, ACC12, ACC12
    vmovdqu64 ACC10, 64*5(res)

    fix2 ACC14, ACC15
    valignq $7, ACC12, ACC14, ACC12
    vmovdqu64 ACC12, 64*6(res)

    fix2 ACC16, ACC17
    valignq $7, ACC16, ACC16, H4

    mov $2, itr1
    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vmovdqu64 64*(\ii+19)(r_ptr), ACC\ii
    .endr
    vmovdqa64 H3, H0

1:
    .irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    vpsrlq $28, ACC\i, H1
    vpandq AND_MASK, ACC\i, ACC\i
    valignq $7, H0, H1, H0
    vpaddq H0, ACC\i, ACC\i
    vmovdqa64 H1, H0
    .endr
    dec itr1
    jnz 1b

    fix2 ACC18, ACC0
    valignq $1, H4, ACC18, H4
    valignq $7, ACC18, ACC18, ACC18
    vmovdqu64 H4, 64*7(res)
    
    fix2 ACC1, ACC2
    valignq $2, ACC18, ACC1, ACC18
    valignq $7, ACC1, ACC1, ACC1
    vmovdqu64 ACC18, 64*8(res)

    fix2 ACC3, ACC4
    valignq $3, ACC1, ACC3, ACC1
    valignq $7, ACC3, ACC3, ACC3
    vmovdqu64 ACC1, 64*9(res)

    fix2 ACC5, ACC6
    valignq $4, ACC3, ACC5, ACC3
    valignq $7, ACC5, ACC5, ACC5
    vmovdqu64 ACC3, 64*10(res)

    fix2 ACC7, ACC8
    valignq $5, ACC5, ACC7, ACC5
    valignq $7, ACC7, ACC7, ACC7
    vmovdqu64 ACC5, 64*11(res)

    fix2 ACC9, ACC10
    valignq $6, ACC7, ACC9, ACC7
    valignq $7, ACC9, ACC9, ACC9
    vmovdqu64 ACC7, 64*12(res)

    fix2 ACC11, ACC12
    valignq $7, ACC9, ACC11, ACC9
    vmovdqu64 ACC9, 64*13(res)

    fix2 ACC13, ACC14
    valignq $7, ACC13, ACC13, ACC13

    fix2 ACC15, ACC16
    valignq $1, ACC13, ACC15, ACC13
    valignq $7, ACC15, ACC15, ACC15
    vmovdqu64 ACC13, 64*14(res)

    vmovdqa64 fixMask0(%rip), H0
    vmovdqa64 fixMask1(%rip), H1
    vpermd ACC17, H0, H0
    vpermw ACC17, H1, H1
    vpermd ACC17, H2, ACC17
    vpsrlvq fixShift0(%rip), H0, H0
    vpsllvq fixShift1(%rip), H1, H1
    vpsllvq fixShift2(%rip), ACC17, ACC17
    vpsllw $8, H1, H1{%k1}
    vpaddq H1, H0, H0
    vpaddq H0, ACC17, ACC17
    vpcmpuq $1, H0, ACC17, %k3
    vpcmpuq $0, M_ONE, ACC17, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq M_ONE, ACC17, ACC17{%k3}

    valignq $2, ACC15, ACC17, ACC15
    vmovdqu64 ACC15, 64*15(res)

    mov %rbp, %rsp
    pop %rbp
    ret

.size mul4096_avx512, .-mul4096_avx512
