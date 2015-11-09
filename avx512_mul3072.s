/*
 *  Multiply two 3072-bit numbers using AVX512F instructions
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

# The result is 6144 bit. ceil(4096/28) = 220. ceil(220/8) = 28.
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27
.set ACC\i, %zmm\i
.endr
# Helper registers
.set ZERO, %zmm28     # zero
.set AND_MASK, %zmm29 # for masking the 28 bits of each qword
.set H0, %zmm30
.set H1, %zmm31
.set H2, ZERO
# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %rax
.set a_ptr, %rcx
.set b_ptr, %rdx

.macro IFMA src1,src2,dst
    vpmuludq \src1, \src2, H1
    vpaddq H1, \dst, \dst
.endm

# void mul3072_avx512(uint64_t res[64], uint64_t a[32], uint64_t b[32]);
.globl mul3072_avx512
.type mul3072_avx512, @function
mul3072_avx512:

    push %rbp
    mov %rsp, %rbp
    sub $(64*30), %rsp
    and $-64, %rsp

    mov   $0x3ff, %ecx
    kmovd %ecx, %k1

    vpbroadcastq andMask(%rip), AND_MASK
    vpxorq ZERO, ZERO, ZERO
    # First we need to convert the input A from radix 2^64 to redundant 2^28
    vmovdqa64 permMask(%rip), H0
    vmovdqa64 shiftMask(%rip), H1
    # Load values with 28-byte intervals and shuffle + shift accordingly
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12
    vpermw 28*\i(a), H0, ACC\i
.endr
    vmovdqu16 28*13(a), ACC13{%k1}{z}
    vpermw ACC13, H0, ACC13
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vpsrlvq H1, ACC\i, ACC\i
.endr
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vpandq AND_MASK, ACC\i, ACC\i
.endr
    # We are storing the converted values of A, with zero padding
    vmovdqa64 ZERO, 64*0(%rsp)
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vmovdqa64 ACC\i, 64*(\i+1)(%rsp)
.endr
    vmovdqa64 ZERO, 64*15(%rsp)
    lea 64*1(%rsp), a_ptr
    # Convert B
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12
    vpermw 28*\i(b), H0, ACC\i
.endr
    vmovdqu16 28*13(b), ACC13{%k1}{z}
    vpermw ACC13, H0, ACC13
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vpsrlvq H1, ACC\i, ACC\i
.endr
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vpandq AND_MASK, ACC\i, ACC\i
.endr
    # We are storing the converted values of B
.irp i,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vmovdqa64 ACC\i, 64*(\i+16)(%rsp)
.endr
    lea 64*16(%rsp), b_ptr

    vpbroadcastq 0*64(b_ptr), H0
    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13
    vpmuludq 64*(\ii)(a_ptr), H0, ACC\ii
    .endr

    vpbroadcastq 1*64(b_ptr), H0
    .irp ii, 1,2,3,4,5,6,7,8,9,10,11,12,13
    IFMA 64*(\ii-1)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC14

    vpbroadcastq 2*64(b_ptr), H0
    .irp ii, 2,3,4,5,6,7,8,9,10,11,12,13,14
    IFMA 64*(\ii-2)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC15

    vpbroadcastq 3*64(b_ptr), H0
    .irp ii, 3,4,5,6,7,8,9,10,11,12,13,14,15
    IFMA 64*(\ii-3)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC16

    vpbroadcastq 4*64(b_ptr), H0
    .irp ii, 4,5,6,7,8,9,10,11,12,13,14,15,16
    IFMA 64*(\ii-4)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC17

    vpbroadcastq 5*64(b_ptr), H0
    .irp ii, 5,6,7,8,9,10,11,12,13,14,15,16,17
    IFMA 64*(\ii-5)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC18

    vpbroadcastq 6*64(b_ptr), H0
    .irp ii, 6,7,8,9,10,11,12,13,14,15,16,17,18
    IFMA 64*(\ii-6)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC19

    vpbroadcastq 7*64(b_ptr), H0
    .irp ii, 7,8,9,10,11,12,13,14,15,16,17,18,19
    IFMA 64*(\ii-7)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC20

    vpbroadcastq 8*64(b_ptr), H0
    .irp ii, 8,9,10,11,12,13,14,15,16,17,18,19,20
    IFMA 64*(\ii-8)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC21

    vpbroadcastq 9*64(b_ptr), H0
    .irp ii, 9,10,11,12,13,14,15,16,17,18,19,20,21
    IFMA 64*(\ii-9)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC22

    vpbroadcastq 10*64(b_ptr), H0
    .irp ii, 10,11,12,13,14,15,16,17,18,19,20,21,22
    IFMA 64*(\ii-10)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC23

    vpbroadcastq 11*64(b_ptr), H0
    .irp ii, 11,12,13,14,15,16,17,18,19,20,21,22,23
    IFMA 64*(\ii-11)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC24

    vpbroadcastq 12*64(b_ptr), H0
    .irp ii, 12,13,14,15,16,17,18,19,20,21,22,23,24
    IFMA 64*(\ii-12)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC25

    vpbroadcastq 13*64(b_ptr), H0
    .irp ii, 13,14,15,16,17,18,19,20,21,22,23,24,25
    IFMA 64*(\ii-13)(a_ptr), H0, ACC\ii
    .endr
    vpmuludq 64*13(a_ptr), H0, ACC26
    vpxorq ACC27, ACC27, ACC27

    add $8, b_ptr
    sub $8, a_ptr

    mov $7, itr1
1:
    vpbroadcastq 0*64(b_ptr), H0
    .irp ii,0,1,2,3,4,5,6,7,8,9,10,11,12,13,14
    IFMA 64*(\ii-0)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 1*64(b_ptr), H0
    .irp ii,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15
    IFMA 64*(\ii-1)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 2*64(b_ptr), H0
    .irp ii,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16
    IFMA 64*(\ii-2)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 3*64(b_ptr), H0
    .irp ii,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17
    IFMA 64*(\ii-3)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 4*64(b_ptr), H0
    .irp ii,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18
    IFMA 64*(\ii-4)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 5*64(b_ptr), H0
    .irp ii,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19
    IFMA 64*(\ii-5)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 6*64(b_ptr), H0
    .irp ii,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20
    IFMA 64*(\ii-6)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 7*64(b_ptr), H0
    .irp ii,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21
    IFMA 64*(\ii-7)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 8*64(b_ptr), H0
    .irp ii,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22
    IFMA 64*(\ii-8)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 9*64(b_ptr), H0
    .irp ii,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23
    IFMA 64*(\ii-9)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 10*64(b_ptr), H0
    .irp ii,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24
    IFMA 64*(\ii-10)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 11*64(b_ptr), H0
    .irp ii,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25
    IFMA 64*(\ii-11)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 12*64(b_ptr), H0
    .irp ii,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
    IFMA 64*(\ii-12)(a_ptr), H0, ACC\ii
    .endr
    vpbroadcastq 13*64(b_ptr), H0
    .irp ii,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27
    IFMA 64*(\ii-13)(a_ptr), H0, ACC\ii
    .endr

    add $8, b_ptr
    sub $8, a_ptr
    dec itr1
    jnz 1b

    mov $2, itr1
1:
    vpsrlq $28, ACC0, H0
    vpandq AND_MASK, ACC0, ACC0
    valignq $7, ZERO, H0, H1
    vpaddq H1, ACC0, ACC0

    .irp i,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27
    vpsrlq $28, ACC\i, H1
    vpandq AND_MASK, ACC\i, ACC\i
    valignq $7, H0, H1, H0
    vpaddq H0, ACC\i, ACC\i
    vmovdqa64 H1, H0
    .endr

    dec itr1
    jnz 1b

    mov $0x8000, %eax
    kmovd %eax, %k1
    vpsubq one(%rip){1to8}, ZERO, AND_MASK

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
    vpcmpuq $0, AND_MASK, \ACC0, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, \ACC0, \ACC0{%k3}
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
    valignq $7, ACC16, ACC16, ACC16

    fix2 ACC18, ACC19
    valignq $1, ACC16, ACC18, ACC16
    valignq $7, ACC18, ACC18, ACC18
    vmovdqu64 ACC16, 64*7(res)

    fix2 ACC20, ACC21
    valignq $2, ACC18, ACC20, ACC18
    valignq $7, ACC20, ACC20, ACC20
    vmovdqu64 ACC18, 64*8(res)

    fix2 ACC22, ACC23
    valignq $3, ACC20, ACC22, ACC20
    valignq $7, ACC22, ACC22, ACC22
    vmovdqu64 ACC20, 64*9(res)

    fix2 ACC24, ACC25
    valignq $4, ACC22, ACC24, ACC22
    valignq $7, ACC24, ACC24, ACC24
    vmovdqu64 ACC22, 64*10(res)

    fix2 ACC26, ACC27
    valignq $5, ACC24, ACC26, ACC24
    vmovdqu64 ACC24, 64*11(res)

    mov %rbp, %rsp
    pop %rbp
    ret
.size mul3072_avx512, .-mul3072_avx512
