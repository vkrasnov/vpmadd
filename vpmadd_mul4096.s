/*
 *  Multiply two 4096-bit numbers using AVX512IFMA instructions
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
# Masks to convert 2^64->2^52
permMask:
.short 0,1,2,3,  3,4,5,6,  6,7,8,9,  9,10,11,12,  13,14,15,16,  16,17,18,19,  19,20,21,22,  22,23,24,25
shiftMask:
.quad  0,4,8,12,0,4,8,12
# Mask to convert 2^52->2^64
.align 64
fixMask0:
.byte  0, 1, 2, 3, 4, 5, 6, 7
.byte  8, 9,10,11,12,13,14,15
.byte 16,17,18,19,20,21,22,23
.byte 24,25,26,27,28,29,30,31
.byte 38,39,-1,-1,-1,-1,-1,48
.byte 48,49,50,51,52,53,54,55
.byte 56,57,58,59,60,61,62,63
.byte 64,65,66,67,68,69,70,71
fixMask1:
.byte  8, 9,10,11,12,13,14,15
.byte 16,17,18,19,20,21,22,23
.byte 24,25,26,27,28,29,30,31
.byte 32,33,34,35,36,37,38,39
.byte 40,41,42,43,44,45,46,47
.byte 47,-1,-1,-1,-1,56,57,58
.byte 64,65,66,67,68,69,70,71
.byte 72,73,74,75,76,77,78,79
fixShift0:
.quad  0,12,24,36, 0, 8,20,32
fixShift1:
.quad 52,40,28,16, 4, 4,32,20

fixMask2:
.byte 13,14,15,-1,-1,-1,-1,24
.byte 24,25,26,27,28,29,30,31
.byte 32,33,34,35,36,37,38,39
.byte 40,41,42,43,44,45,46,47
.byte 48,49,50,51,52,53,54,55
.byte -1,-1,-1,-1,-1,-1,-1,-1
.byte -1,-1,-1,-1,-1,-1,-1,-1
.byte -1,-1,-1,-1,-1,-1,-1,-1
fixMask3:
.byte 16,17,18,19,20,21,22,23
.byte 23, 7, 7, 7, 7, 7,32,33
.byte 40,41,42,43,44,45,46,47
.byte 48,49,50,51,52,53,54,55
.byte 56,57,58,59,60,61,62,64
.byte -1,-1,-1,-1,-1,-1,-1,-1
.byte -1,-1,-1,-1,-1,-1,-1,-1
.byte -1,-1,-1,-1,-1,-1,-1,-1
fixShift2:
.quad  4, 4,16,28,40,64,64,64
fixShift3:
.quad  8, 0,36,24,12,64,64,64

# The constant 1
one:
.quad 1

.set ACC0, %zmm0
.set ACC1, %zmm1
.set ACC2, %zmm2
.set ACC3, %zmm3
.set ACC4, %zmm4
.set ACC5, %zmm5
.set ACC6, %zmm6
.set ACC7, %zmm7
.set ACC8, %zmm8
.set ACC9, %zmm9
.set ACC10, %zmm10
.set ACC11, %zmm11
.set ACC12, %zmm12
.set ACC13, %zmm13
.set ACC14, %zmm14
.set ACC15, %zmm15
.set ACC16, %zmm16
.set ACC17, %zmm17
.set ACC18, %zmm18
.set ACC19, %zmm19

# Helper registers
.set ZERO, %zmm20     # always zero
.set MINUS_ONE, %zmm21

.set T0, %zmm22
.set T1, %zmm23
.set T2, %zmm24
.set T3, %zmm25
.set T4, %zmm26
.set T5, %zmm27
.set T6, %zmm28
.set T7, %zmm29
.set T8, %zmm30
.set T9, %zmm31
# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %rax
.set a_ptr, %rcx
.set b_ptr, %rdx

# void mul4096_vpmadd(uint64_t res[96], uint64_t a[48], uint64_t b[48]);
.globl mul4096_vpmadd
.type mul4096_vpmadd, @function
mul4096_vpmadd:
    push %rbp
    mov %rsp, %rbp
    sub $(64*22), %rsp
    and $-64, %rsp

    mov   $0x3FFFFF, %ecx
    kmovd %ecx, %k1

    vpxorq ZERO, ZERO, ZERO
    # First we need to convert the input from radix 2^64 to redundant 2^52
    vmovdqa64 permMask(%rip), T0
    vmovdqa64 shiftMask(%rip), T1
    # Load values with 52-byte intervals and shuffle + shift accordingly

    # Convert and store A
    vpermw 52*0(a), T0, ACC0
    vpermw 52*1(a), T0, ACC1
    vpermw 52*2(a), T0, ACC2
    vpermw 52*3(a), T0, ACC3
    vpermw 52*4(a), T0, ACC4
    vpermw 52*5(a), T0, ACC5
    vpermw 52*6(a), T0, ACC6
    vpermw 52*7(a), T0, ACC7
    vpermw 52*8(a), T0, ACC8
    vmovdqu16 52*9(a), ACC9{%k1}{z}
    vpermw ACC9, T0, ACC9

    vpsrlvq T1, ACC0, ACC0
    vpsrlvq T1, ACC1, ACC1
    vpsrlvq T1, ACC2, ACC2
    vpsrlvq T1, ACC3, ACC3
    vpsrlvq T1, ACC4, ACC4
    vpsrlvq T1, ACC5, ACC5
    vpsrlvq T1, ACC6, ACC6
    vpsrlvq T1, ACC7, ACC7
    vpsrlvq T1, ACC8, ACC8
    vpsrlvq T1, ACC9, ACC9
    vpxorq ACC10, ACC10, ACC10

    vmovdqu64 ACC10, 64*0(%rsp)
    vmovdqu64 ACC0, 64*1(%rsp)
    vmovdqu64 ACC1, 64*2(%rsp)
    vmovdqu64 ACC2, 64*3(%rsp)
    vmovdqu64 ACC3, 64*4(%rsp)
    vmovdqu64 ACC4, 64*5(%rsp)
    vmovdqu64 ACC5, 64*6(%rsp)
    vmovdqu64 ACC6, 64*7(%rsp)
    vmovdqu64 ACC7, 64*8(%rsp)
    vmovdqu64 ACC8, 64*9(%rsp)
    vmovdqu64 ACC9, 64*10(%rsp)
    vmovdqu64 ACC10, 64*11(%rsp)
    lea 64*1(%rsp), a_ptr
    # Then B
    vpermw 52*0(b), T0, ACC0
    vpermw 52*1(b), T0, ACC1
    vpermw 52*2(b), T0, ACC2
    vpermw 52*3(b), T0, ACC3
    vpermw 52*4(b), T0, ACC4
    vpermw 52*5(b), T0, ACC5
    vpermw 52*6(b), T0, ACC6
    vpermw 52*7(b), T0, ACC7
    vpermw 52*8(b), T0, ACC8
    vmovdqu16 52*9(b), ACC9{%k1}{z}
    vpermw ACC9, T0, ACC9

    vpsrlvq T1, ACC0, ACC0
    vpsrlvq T1, ACC1, ACC1
    vpsrlvq T1, ACC2, ACC2
    vpsrlvq T1, ACC3, ACC3
    vpsrlvq T1, ACC4, ACC4
    vpsrlvq T1, ACC5, ACC5
    vpsrlvq T1, ACC6, ACC6
    vpsrlvq T1, ACC7, ACC7
    vpsrlvq T1, ACC8, ACC8
    vpsrlvq T1, ACC9, ACC9

    vmovdqu64 ACC0, 64*12(%rsp)
    vmovdqu64 ACC1, 64*13(%rsp)
    vmovdqu64 ACC2, 64*14(%rsp)
    vmovdqu64 ACC3, 64*15(%rsp)
    vmovdqu64 ACC4, 64*16(%rsp)
    vmovdqu64 ACC5, 64*17(%rsp)
    vmovdqu64 ACC6, 64*18(%rsp)
    vmovdqu64 ACC7, 64*19(%rsp)
    vmovdqu64 ACC8, 64*20(%rsp)
    vmovdqu64 ACC9, 64*21(%rsp)
    lea 64*12(%rsp), b_ptr
    # Zero the accumulators, since IFMA must always add
    vpxorq ACC0, ACC0, ACC0
    vpxorq ACC1, ACC1, ACC1
    vpxorq ACC2, ACC2, ACC2
    vpxorq ACC3, ACC3, ACC3
    vpxorq ACC4, ACC4, ACC4
    vpxorq ACC5, ACC5, ACC5
    vpxorq ACC6, ACC6, ACC6
    vpxorq ACC7, ACC7, ACC7
    vpxorq ACC8, ACC8, ACC8
    vpxorq ACC9, ACC9, ACC9
    vpxorq ACC10, ACC10, ACC10
    vpxorq ACC11, ACC11, ACC11
    vpxorq ACC12, ACC12, ACC12
    vpxorq ACC13, ACC13, ACC13
    vpxorq ACC14, ACC14, ACC14
    vpxorq ACC15, ACC15, ACC15
    vpxorq ACC16, ACC16, ACC16
    vpxorq ACC17, ACC17, ACC17
    vpxorq ACC18, ACC18, ACC18
    vpxorq ACC19, ACC19, ACC19
    # The classic approach is to multiply by a single digit of B
    # each iteration, however we prefer to multiply by all digits
    # with 8-digit interval, while the registers are aligned, and then
    # shift. We have a total of 79 digits
    mov $8, itr1
1:
        vpbroadcastq 0*64(b_ptr), T0
        # Multiply the correctly aligned values
        vpmadd52luq 64*0(a_ptr), T0, ACC0
        vpmadd52luq 64*1(a_ptr), T0, ACC1
        vpmadd52luq 64*2(a_ptr), T0, ACC2
        vpmadd52luq 64*3(a_ptr), T0, ACC3
        vpmadd52luq 64*4(a_ptr), T0, ACC4
        vpmadd52luq 64*5(a_ptr), T0, ACC5
        vpmadd52luq 64*6(a_ptr), T0, ACC6
        vpmadd52luq 64*7(a_ptr), T0, ACC7
        vpmadd52luq 64*8(a_ptr), T0, ACC8
        vpmadd52luq 64*9(a_ptr), T0, ACC9
        vpmadd52luq 64*10(a_ptr), T0, ACC10
        vpbroadcastq 1*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC1
        vpmadd52luq 64*1(a_ptr), T0, ACC2
        vpmadd52luq 64*2(a_ptr), T0, ACC3
        vpmadd52luq 64*3(a_ptr), T0, ACC4
        vpmadd52luq 64*4(a_ptr), T0, ACC5
        vpmadd52luq 64*5(a_ptr), T0, ACC6
        vpmadd52luq 64*6(a_ptr), T0, ACC7
        vpmadd52luq 64*7(a_ptr), T0, ACC8
        vpmadd52luq 64*8(a_ptr), T0, ACC9
        vpmadd52luq 64*9(a_ptr), T0, ACC10
        vpmadd52luq 64*10(a_ptr), T0, ACC11
        vpbroadcastq 2*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC2
        vpmadd52luq 64*1(a_ptr), T0, ACC3
        vpmadd52luq 64*2(a_ptr), T0, ACC4
        vpmadd52luq 64*3(a_ptr), T0, ACC5
        vpmadd52luq 64*4(a_ptr), T0, ACC6
        vpmadd52luq 64*5(a_ptr), T0, ACC7
        vpmadd52luq 64*6(a_ptr), T0, ACC8
        vpmadd52luq 64*7(a_ptr), T0, ACC9
        vpmadd52luq 64*8(a_ptr), T0, ACC10
        vpmadd52luq 64*9(a_ptr), T0, ACC11
        vpmadd52luq 64*10(a_ptr), T0, ACC12
        vpbroadcastq 3*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC3
        vpmadd52luq 64*1(a_ptr), T0, ACC4
        vpmadd52luq 64*2(a_ptr), T0, ACC5
        vpmadd52luq 64*3(a_ptr), T0, ACC6
        vpmadd52luq 64*4(a_ptr), T0, ACC7
        vpmadd52luq 64*5(a_ptr), T0, ACC8
        vpmadd52luq 64*6(a_ptr), T0, ACC9
        vpmadd52luq 64*7(a_ptr), T0, ACC10
        vpmadd52luq 64*8(a_ptr), T0, ACC11
        vpmadd52luq 64*9(a_ptr), T0, ACC12
        vpmadd52luq 64*10(a_ptr), T0, ACC13
        vpbroadcastq 4*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC4
        vpmadd52luq 64*1(a_ptr), T0, ACC5
        vpmadd52luq 64*2(a_ptr), T0, ACC6
        vpmadd52luq 64*3(a_ptr), T0, ACC7
        vpmadd52luq 64*4(a_ptr), T0, ACC8
        vpmadd52luq 64*5(a_ptr), T0, ACC9
        vpmadd52luq 64*6(a_ptr), T0, ACC10
        vpmadd52luq 64*7(a_ptr), T0, ACC11
        vpmadd52luq 64*8(a_ptr), T0, ACC12
        vpmadd52luq 64*9(a_ptr), T0, ACC13
        vpmadd52luq 64*10(a_ptr), T0, ACC14
        vpbroadcastq 5*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC5
        vpmadd52luq 64*1(a_ptr), T0, ACC6
        vpmadd52luq 64*2(a_ptr), T0, ACC7
        vpmadd52luq 64*3(a_ptr), T0, ACC8
        vpmadd52luq 64*4(a_ptr), T0, ACC9
        vpmadd52luq 64*5(a_ptr), T0, ACC10
        vpmadd52luq 64*6(a_ptr), T0, ACC11
        vpmadd52luq 64*7(a_ptr), T0, ACC12
        vpmadd52luq 64*8(a_ptr), T0, ACC13
        vpmadd52luq 64*9(a_ptr), T0, ACC14
        vpmadd52luq 64*10(a_ptr), T0, ACC15
        vpbroadcastq 6*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC6
        vpmadd52luq 64*1(a_ptr), T0, ACC7
        vpmadd52luq 64*2(a_ptr), T0, ACC8
        vpmadd52luq 64*3(a_ptr), T0, ACC9
        vpmadd52luq 64*4(a_ptr), T0, ACC10
        vpmadd52luq 64*5(a_ptr), T0, ACC11
        vpmadd52luq 64*6(a_ptr), T0, ACC12
        vpmadd52luq 64*7(a_ptr), T0, ACC13
        vpmadd52luq 64*8(a_ptr), T0, ACC14
        vpmadd52luq 64*9(a_ptr), T0, ACC15
        vpmadd52luq 64*10(a_ptr), T0, ACC16
        vpbroadcastq 7*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC7
        vpmadd52luq 64*1(a_ptr), T0, ACC8
        vpmadd52luq 64*2(a_ptr), T0, ACC9
        vpmadd52luq 64*3(a_ptr), T0, ACC10
        vpmadd52luq 64*4(a_ptr), T0, ACC11
        vpmadd52luq 64*5(a_ptr), T0, ACC12
        vpmadd52luq 64*6(a_ptr), T0, ACC13
        vpmadd52luq 64*7(a_ptr), T0, ACC14
        vpmadd52luq 64*8(a_ptr), T0, ACC15
        vpmadd52luq 64*9(a_ptr), T0, ACC16
        vpmadd52luq 64*10(a_ptr), T0, ACC17
        vpbroadcastq 8*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC8
        vpmadd52luq 64*1(a_ptr), T0, ACC9
        vpmadd52luq 64*2(a_ptr), T0, ACC10
        vpmadd52luq 64*3(a_ptr), T0, ACC11
        vpmadd52luq 64*4(a_ptr), T0, ACC12
        vpmadd52luq 64*5(a_ptr), T0, ACC13
        vpmadd52luq 64*6(a_ptr), T0, ACC14
        vpmadd52luq 64*7(a_ptr), T0, ACC15
        vpmadd52luq 64*8(a_ptr), T0, ACC16
        vpmadd52luq 64*9(a_ptr), T0, ACC17
        vpmadd52luq 64*10(a_ptr), T0, ACC18
        vpbroadcastq 9*64(b_ptr), T0
        vpmadd52luq 64*0(a_ptr), T0, ACC9
        vpmadd52luq 64*1(a_ptr), T0, ACC10
        vpmadd52luq 64*2(a_ptr), T0, ACC11
        vpmadd52luq 64*3(a_ptr), T0, ACC12
        vpmadd52luq 64*4(a_ptr), T0, ACC13
        vpmadd52luq 64*5(a_ptr), T0, ACC14
        vpmadd52luq 64*6(a_ptr), T0, ACC15
        vpmadd52luq 64*7(a_ptr), T0, ACC16
        vpmadd52luq 64*8(a_ptr), T0, ACC17
        vpmadd52luq 64*9(a_ptr), T0, ACC18
        vpmadd52luq 64*10(a_ptr), T0, ACC19

        sub $8, a_ptr

        vpbroadcastq 0*64(b_ptr), T0
        # Multiply the correctly aligned values
        vpmadd52huq 64*0(a_ptr), T0, ACC0
        vpmadd52huq 64*1(a_ptr), T0, ACC1
        vpmadd52huq 64*2(a_ptr), T0, ACC2
        vpmadd52huq 64*3(a_ptr), T0, ACC3
        vpmadd52huq 64*4(a_ptr), T0, ACC4
        vpmadd52huq 64*5(a_ptr), T0, ACC5
        vpmadd52huq 64*6(a_ptr), T0, ACC6
        vpmadd52huq 64*7(a_ptr), T0, ACC7
        vpmadd52huq 64*8(a_ptr), T0, ACC8
        vpmadd52huq 64*9(a_ptr), T0, ACC9
        vpmadd52huq 64*10(a_ptr), T0, ACC10
        vpbroadcastq 1*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC1
        vpmadd52huq 64*1(a_ptr), T0, ACC2
        vpmadd52huq 64*2(a_ptr), T0, ACC3
        vpmadd52huq 64*3(a_ptr), T0, ACC4
        vpmadd52huq 64*4(a_ptr), T0, ACC5
        vpmadd52huq 64*5(a_ptr), T0, ACC6
        vpmadd52huq 64*6(a_ptr), T0, ACC7
        vpmadd52huq 64*7(a_ptr), T0, ACC8
        vpmadd52huq 64*8(a_ptr), T0, ACC9
        vpmadd52huq 64*9(a_ptr), T0, ACC10
        vpmadd52huq 64*10(a_ptr), T0, ACC11
        vpbroadcastq 2*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC2
        vpmadd52huq 64*1(a_ptr), T0, ACC3
        vpmadd52huq 64*2(a_ptr), T0, ACC4
        vpmadd52huq 64*3(a_ptr), T0, ACC5
        vpmadd52huq 64*4(a_ptr), T0, ACC6
        vpmadd52huq 64*5(a_ptr), T0, ACC7
        vpmadd52huq 64*6(a_ptr), T0, ACC8
        vpmadd52huq 64*7(a_ptr), T0, ACC9
        vpmadd52huq 64*8(a_ptr), T0, ACC10
        vpmadd52huq 64*9(a_ptr), T0, ACC11
        vpmadd52huq 64*10(a_ptr), T0, ACC12
        vpbroadcastq 3*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC3
        vpmadd52huq 64*1(a_ptr), T0, ACC4
        vpmadd52huq 64*2(a_ptr), T0, ACC5
        vpmadd52huq 64*3(a_ptr), T0, ACC6
        vpmadd52huq 64*4(a_ptr), T0, ACC7
        vpmadd52huq 64*5(a_ptr), T0, ACC8
        vpmadd52huq 64*6(a_ptr), T0, ACC9
        vpmadd52huq 64*7(a_ptr), T0, ACC10
        vpmadd52huq 64*8(a_ptr), T0, ACC11
        vpmadd52huq 64*9(a_ptr), T0, ACC12
        vpmadd52huq 64*10(a_ptr), T0, ACC13
        vpbroadcastq 4*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC4
        vpmadd52huq 64*1(a_ptr), T0, ACC5
        vpmadd52huq 64*2(a_ptr), T0, ACC6
        vpmadd52huq 64*3(a_ptr), T0, ACC7
        vpmadd52huq 64*4(a_ptr), T0, ACC8
        vpmadd52huq 64*5(a_ptr), T0, ACC9
        vpmadd52huq 64*6(a_ptr), T0, ACC10
        vpmadd52huq 64*7(a_ptr), T0, ACC11
        vpmadd52huq 64*8(a_ptr), T0, ACC12
        vpmadd52huq 64*9(a_ptr), T0, ACC13
        vpmadd52huq 64*10(a_ptr), T0, ACC14
        vpbroadcastq 5*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC5
        vpmadd52huq 64*1(a_ptr), T0, ACC6
        vpmadd52huq 64*2(a_ptr), T0, ACC7
        vpmadd52huq 64*3(a_ptr), T0, ACC8
        vpmadd52huq 64*4(a_ptr), T0, ACC9
        vpmadd52huq 64*5(a_ptr), T0, ACC10
        vpmadd52huq 64*6(a_ptr), T0, ACC11
        vpmadd52huq 64*7(a_ptr), T0, ACC12
        vpmadd52huq 64*8(a_ptr), T0, ACC13
        vpmadd52huq 64*9(a_ptr), T0, ACC14
        vpmadd52huq 64*10(a_ptr), T0, ACC15
        vpbroadcastq 6*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC6
        vpmadd52huq 64*1(a_ptr), T0, ACC7
        vpmadd52huq 64*2(a_ptr), T0, ACC8
        vpmadd52huq 64*3(a_ptr), T0, ACC9
        vpmadd52huq 64*4(a_ptr), T0, ACC10
        vpmadd52huq 64*5(a_ptr), T0, ACC11
        vpmadd52huq 64*6(a_ptr), T0, ACC12
        vpmadd52huq 64*7(a_ptr), T0, ACC13
        vpmadd52huq 64*8(a_ptr), T0, ACC14
        vpmadd52huq 64*9(a_ptr), T0, ACC15
        vpmadd52huq 64*10(a_ptr), T0, ACC16
        vpbroadcastq 7*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC7
        vpmadd52huq 64*1(a_ptr), T0, ACC8
        vpmadd52huq 64*2(a_ptr), T0, ACC9
        vpmadd52huq 64*3(a_ptr), T0, ACC10
        vpmadd52huq 64*4(a_ptr), T0, ACC11
        vpmadd52huq 64*5(a_ptr), T0, ACC12
        vpmadd52huq 64*6(a_ptr), T0, ACC13
        vpmadd52huq 64*7(a_ptr), T0, ACC14
        vpmadd52huq 64*8(a_ptr), T0, ACC15
        vpmadd52huq 64*9(a_ptr), T0, ACC16
        vpmadd52huq 64*10(a_ptr), T0, ACC17
        vpbroadcastq 8*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC8
        vpmadd52huq 64*1(a_ptr), T0, ACC9
        vpmadd52huq 64*2(a_ptr), T0, ACC10
        vpmadd52huq 64*3(a_ptr), T0, ACC11
        vpmadd52huq 64*4(a_ptr), T0, ACC12
        vpmadd52huq 64*5(a_ptr), T0, ACC13
        vpmadd52huq 64*6(a_ptr), T0, ACC14
        vpmadd52huq 64*7(a_ptr), T0, ACC15
        vpmadd52huq 64*8(a_ptr), T0, ACC16
        vpmadd52huq 64*9(a_ptr), T0, ACC17
        vpmadd52huq 64*10(a_ptr), T0, ACC18
        vpbroadcastq 9*64(b_ptr), T0
        vpmadd52huq 64*0(a_ptr), T0, ACC9
        vpmadd52huq 64*1(a_ptr), T0, ACC10
        vpmadd52huq 64*2(a_ptr), T0, ACC11
        vpmadd52huq 64*3(a_ptr), T0, ACC12
        vpmadd52huq 64*4(a_ptr), T0, ACC13
        vpmadd52huq 64*5(a_ptr), T0, ACC14
        vpmadd52huq 64*6(a_ptr), T0, ACC15
        vpmadd52huq 64*7(a_ptr), T0, ACC16
        vpmadd52huq 64*8(a_ptr), T0, ACC17
        vpmadd52huq 64*9(a_ptr), T0, ACC18
        vpmadd52huq 64*10(a_ptr), T0, ACC19

        add $8, b_ptr
        dec itr1
    jnz 1b
    # And convert to radix 2^64
    # This step can be avoided if the result will be used for other
    # operations in radix 2^52
    valignq $7, ACC1, ZERO, T0
    valignq $7, ACC3, ZERO, T1
    valignq $7, ACC5, ZERO, T2
    valignq $7, ACC7, ZERO, T3
    valignq $7, ACC9, ZERO, T4
    valignq $7, ACC11, ZERO, T5
    valignq $7, ACC13, ZERO, T6
    valignq $7, ACC15, ZERO, T7
    valignq $7, ACC17, ZERO, T8
    vpsrlq $52, T0, T0
    vpsrlq $52, T1, T1
    vpsrlq $52, T2, T2
    vpsrlq $52, T3, T3
    vpsrlq $52, T4, T4
    vpsrlq $52, T5, T5
    vpsrlq $52, T6, T6
    vpsrlq $52, T7, T7
    vpsrlq $52, T8, T8
    vpaddq T0, ACC2, ACC2
    vpaddq T1, ACC4, ACC4
    vpaddq T2, ACC6, ACC6
    vpaddq T3, ACC8, ACC8
    vpaddq T4, ACC10, ACC10
    vpaddq T5, ACC12, ACC12
    vpaddq T6, ACC14, ACC14
    vpaddq T7, ACC16, ACC16
    vpaddq T8, ACC18, ACC18

    # Prepare required masks
    vpsubq one(%rip){1to8}, ZERO, MINUS_ONE
    mov $0x400, %eax
    kmovd %eax, %k2
    mov $0xFFFFFF83FFFFFFFF, %rax
    kmovq %rax, %k3
    mov $0xFFFFE1FFFFFFFFFF, %rax
    kmovq %rax, %k4
    mov $0xFFFFFFFFFFFFFF87, %rax
    kmovq %rax, %k5
    mov $0xFFFFFFFFFFFFC1FF, %rax
    kmovq %rax, %k6
    mov $0x2, %eax
    kmovd %eax, %k7
    mov $5, %edx

    vmovdqa64 fixMask1(%rip), T4
    vmovdqa64 fixMask2(%rip), T2
    vmovdqa64 fixMask3(%rip), T3
    # 16 redundant words = 13 normal words
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC1, ACC0, T0{%k3}{z}
    vpermt2b ACC1, T4, ACC0{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC0, ACC0
    vpsrld $8, ACC0, ACC0{%k2}

    vpermb ACC1, T2, T0{%k5}{z}
    vpermb ACC1, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC1
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC1, ACC1{%k7}
    # Add and propagate carry
    vpaddq T5, ACC0, ACC0
    vpaddq T6, ACC1, ACC1
    vpcmpuq $1, T5, ACC0, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC0, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC1, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC1, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC0, ACC0{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC1, ACC1{%k1}

    valignq $5, ACC1, ACC1, ACC1
    vmovdqu64 ACC0, 64*0(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC3, ACC2, T0{%k3}{z}
    vpermt2b ACC3, T4, ACC2{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC2, ACC2
    vpsrld $8, ACC2, ACC2{%k2}

    vpermb ACC3, T2, T0{%k5}{z}
    vpermb ACC3, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC3
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC3, ACC3{%k7}

    vpaddq T5, ACC2, ACC2
    vpaddq T6, ACC3, ACC3
    vpcmpuq $1, T5, ACC2, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC2, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC3, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC3, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC2, ACC2{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC3, ACC3{%k1}

    mov $0xe0, %eax
    kmovd %eax, %k1
    valignq $3, ACC1, ACC2, ACC1
    valignq $3, ACC2, ACC3, ACC2
    valignq $5, ACC3, ACC3, ACC3

    vmovdqu64 ACC1, 64*1(res)
    vmovdqu64 ACC2, 64*2(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC5, ACC4, T0{%k3}{z}
    vpermt2b ACC5, T4, ACC4{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC4, ACC4
    vpsrld $8, ACC4, ACC4{%k2}

    vpermb ACC5, T2, T0{%k5}{z}
    vpermb ACC5, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC5
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC5, ACC5{%k7}

    vpaddq T5, ACC4, ACC4
    vpaddq T6, ACC5, ACC5
    vpcmpuq $1, T5, ACC4, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC4, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC5, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC5, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC4, ACC4{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC5, ACC5{%k1}

    valignq $6, ACC3, ACC4, ACC3
    valignq $5, ACC4, ACC5, ACC4
    vmovdqu64 ACC3, 64*3(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC7, ACC6, T0{%k3}{z}
    vpermt2b ACC7, T4, ACC6{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC6, ACC6
    vpsrld $8, ACC6, ACC6{%k2}

    vpermb ACC7, T2, T0{%k5}{z}
    vpermb ACC7, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC7
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC7, ACC7{%k7}

    vpaddq T5, ACC6, ACC6
    vpaddq T6, ACC7, ACC7
    vpcmpuq $1, T5, ACC6, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC6, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC7, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC7, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC6, ACC6{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC7, ACC7{%k1}

    valignq $1, ACC4, ACC6, ACC4
    valignq $1, ACC6, ACC7, ACC5
    valignq $5, ACC7, ACC7, ACC6

    vmovdqu64 ACC4, 64*4(res)
    vmovdqu64 ACC5, 64*5(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC9, ACC8, T0{%k3}{z}
    vpermt2b ACC9, T4, ACC8{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC8, ACC8
    vpsrld $8, ACC8, ACC8{%k2}

    vpermb ACC9, T2, T0{%k5}{z}
    vpermb ACC9, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC9
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC9, ACC9{%k7}

    vpaddq T5, ACC8, ACC8
    vpaddq T6, ACC9, ACC9
    vpcmpuq $1, T5, ACC8, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC8, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC9, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC9, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC8, ACC8{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC9, ACC9{%k1}

    valignq $4, ACC6, ACC8, ACC6
    valignq $4, ACC8, ACC9, ACC7
    valignq $5, ACC9, ACC9, ACC8

    vmovdqu64 ACC6, 64*6(res)
    vmovdqu64 ACC7, 64*7(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC11, ACC10, T0{%k3}{z}
    vpermt2b ACC11, T4, ACC10{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC10, ACC10
    vpsrld $8, ACC10, ACC10{%k2}

    vpermb ACC11, T2, T0{%k5}{z}
    vpermb ACC11, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC11
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC11, ACC11{%k7}

    vpaddq T5, ACC10, ACC10
    vpaddq T6, ACC11, ACC11
    vpcmpuq $1, T5, ACC10, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC10, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC11, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC11, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC10, ACC10{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC11, ACC11{%k1}

    valignq $7, ACC8, ACC10, ACC8
    valignq $5, ACC10, ACC11, ACC9
    vmovdqu64 ACC8, 64*8(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC13, ACC12, T0{%k3}{z}
    vpermt2b ACC13, T4, ACC12{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC12, ACC12
    vpsrld $8, ACC12, ACC12{%k2}

    vpermb ACC13, T2, T0{%k5}{z}
    vpermb ACC13, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC13
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC13, ACC13{%k7}

    vpaddq T5, ACC12, ACC12
    vpaddq T6, ACC13, ACC13
    vpcmpuq $1, T5, ACC12, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC12, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC13, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC13, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC12, ACC12{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC13, ACC13{%k1}

    valignq $2, ACC9, ACC12, ACC9
    valignq $2, ACC12, ACC13, ACC10
    valignq $5, ACC13, ACC13, ACC11
    vmovdqu64 ACC9, 64*9(res)
    vmovdqu64 ACC10, 64*10(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC15, ACC14, T0{%k3}{z}
    vpermt2b ACC15, T4, ACC14{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC14, ACC14
    vpsrld $8, ACC14, ACC14{%k2}

    vpermb ACC15, T2, T0{%k5}{z}
    vpermb ACC15, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC15
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC15, ACC15{%k7}

    vpaddq T5, ACC14, ACC14
    vpaddq T6, ACC15, ACC15
    vpcmpuq $1, T5, ACC14, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC14, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC15, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC15, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC14, ACC14{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC15, ACC15{%k1}

    valignq $5, ACC11, ACC14, ACC11
    valignq $5, ACC14, ACC15, ACC12
    vmovdqu64 ACC11, 64*11(res)
    vmovdqu64 ACC12, 64*12(res)
    # Next pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC17, ACC16, T0{%k3}{z}
    vpermt2b ACC17, T4, ACC16{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC16, ACC16
    vpsrld $8, ACC16, ACC16{%k2}

    vpermb ACC17, T2, T0{%k5}{z}
    vpermb ACC17, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC17
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC17, ACC17{%k7}

    vpaddq T5, ACC16, ACC16
    vpaddq T6, ACC17, ACC17
    vpcmpuq $1, T5, ACC16, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC16, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC17, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC17, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    shrx %edx, %ecx, %r10d
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC16, ACC16{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC17, ACC17{%k1}

    valignq $5, ACC17, ACC17, ACC14
    vmovdqu64 ACC16, 64*13(res)
    # Last pair
    vmovdqa64 fixMask0(%rip), T0
    vpermi2b ACC19, ACC18, T0{%k3}{z}
    vpermt2b ACC19, T4, ACC18{%k4}{z}
    vpsrlvq fixShift0(%rip), T0, T5
    vpsllvq fixShift1(%rip), ACC18, ACC18
    vpsrld $8, ACC18, ACC18{%k2}

    vpermb ACC19, T2, T0{%k5}{z}
    vpermb ACC19, T3, T1{%k6}{z}
    vpsrlvq fixShift2(%rip), T0, ACC19
    vpsllvq fixShift3(%rip), T1, T6
    vpslld $8, ACC19, ACC19{%k7}

    vpaddq T5, ACC18, ACC18
    vpaddq T6, ACC19, ACC19
    vpcmpuq $1, T5, ACC18, %k1
    kmovb %k1, %eax
    vpcmpuq $0, MINUS_ONE, ACC18, %k1
    kmovb %k1, %r8d
    vpcmpuq $1, T6, ACC19, %k1
    kmovb %k1, %ecx
    vpcmpuq $0, MINUS_ONE, ACC19, %k1
    kmovb %k1, %r9d
    add %al, %al
    adc %cl, %cl
    add %r10b, %al
    adc $0, %cl
    add %r8b, %al
    adc %r9b, %cl
    xor %r8b, %al
    xor %r9b, %cl
    kmovb %eax, %k1
    vpsubq MINUS_ONE, ACC18, ACC18{%k1}
    kmovb %ecx, %k1
    vpsubq MINUS_ONE, ACC19, ACC19{%k1}

    valignq $3, ACC14, ACC18, ACC14
    valignq $3, ACC18, ACC19, ACC15

    vmovdqu64 ACC14, 14*64(res)
    vmovdqu64 ACC15, 15*64(res)

    mov %rbp, %rsp
    pop %rbp
    ret
.size mul4096_vpmadd, .-mul4096_vpmadd
