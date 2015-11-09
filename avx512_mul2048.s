/*
 *  Multiply two 2048-bit numbers using AVX512F instructions
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

# The result is 4096 bit. ceil(4096/28) = 147. ceil(147/8) = 19.
# Therefore 9 registers for the result.
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
# The inputs are 2048 bit. ceil(2048/28) = 74. ceil(74/8) = 10.
.set A0, %zmm19
.set A1, %zmm20
.set A2, %zmm21
.set A3, %zmm22
.set A4, %zmm23
.set A5, %zmm24
.set A6, %zmm25
.set A7, %zmm26
.set A8, %zmm27
.set A9, %zmm28
.set A10, %zmm29

# Helper registers
.set ZERO, %zmm30     # always zero
.set AND_MASK, %zmm31 # for masking the 28 bits of each qword
.set H0, AND_MASK
.set H1, ZERO
# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %rax
.set itr2, %rcx

.macro IFMA src1,src2,dst
    vpmuludq \src1, \src2, H1
    vpaddq H1, \dst, \dst
.endm


# void mul2048_avx512(uint64_t res[64], uint64_t a[32], uint64_t b[32]);
.globl mul2048_avx512
.type mul2048_avx512, @function
mul2048_avx512:

    push %rbp
    mov %rsp, %rbp
    sub $(64*10), %rsp
    and $-64, %rsp

    mov   $0x3, %ecx
    kmovd %ecx, %k1

    # First we need to convert the input A from radix 2^64 to redundant 2^28
    vmovdqa64 permMask(%rip), H0
    vmovdqa64 shiftMask(%rip), H1
    # Load values with 28-byte intervals and shuffle + shift accordingly
    vpermw 28*0(b), H0, A0
    vpermw 28*1(b), H0, A1
    vpermw 28*2(b), H0, A2
    vpermw 28*3(b), H0, A3
    vpermw 28*4(b), H0, A4
    vpermw 28*5(b), H0, A5
    vpermw 28*6(b), H0, A6
    vpermw 28*7(b), H0, A7
    vpermw 28*8(b), H0, A8
    vmovdqu16 28*9(b), A9{%k1}{z}
    vpermw A9, H0, A9

    vpsrlvq H1, A0, A0
    vpsrlvq H1, A1, A1
    vpsrlvq H1, A2, A2
    vpsrlvq H1, A3, A3
    vpsrlvq H1, A4, A4
    vpsrlvq H1, A5, A5
    vpsrlvq H1, A6, A6
    vpsrlvq H1, A7, A7
    vpsrlvq H1, A8, A8
    vpsrlvq H1, A9, A9

    vpbroadcastq andMask(%rip), AND_MASK
    vpandq AND_MASK, A0, A0
    vpandq AND_MASK, A1, A1
    vpandq AND_MASK, A2, A2
    vpandq AND_MASK, A3, A3
    vpandq AND_MASK, A4, A4
    vpandq AND_MASK, A5, A5
    vpandq AND_MASK, A6, A6
    vpandq AND_MASK, A7, A7
    vpandq AND_MASK, A8, A8
    vpandq AND_MASK, A9, A9

    # We are storing the converted values of B
    vmovdqa64 A0, 64*0(%rsp)
    vmovdqa64 A1, 64*1(%rsp)
    vmovdqa64 A2, 64*2(%rsp)
    vmovdqa64 A3, 64*3(%rsp)
    vmovdqa64 A4, 64*4(%rsp)
    vmovdqa64 A5, 64*5(%rsp)
    vmovdqa64 A6, 64*6(%rsp)
    vmovdqa64 A7, 64*7(%rsp)
    vmovdqa64 A8, 64*8(%rsp)
    vmovdqa64 A9, 64*9(%rsp)

    vmovdqa64 permMask(%rip), H0
    vmovdqa64 shiftMask(%rip), H1
    vpermw 28*0(a), H0, A0
    vpermw 28*1(a), H0, A1
    vpermw 28*2(a), H0, A2
    vpermw 28*3(a), H0, A3
    vpermw 28*4(a), H0, A4
    vpermw 28*5(a), H0, A5
    vpermw 28*6(a), H0, A6
    vpermw 28*7(a), H0, A7
    vpermw 28*8(a), H0, A8
    vmovdqu16 28*9(a), A9{%k1}{z}
    vpermw A9, H0, A9

    vpsrlvq H1, A0, A0
    vpsrlvq H1, A1, A1
    vpsrlvq H1, A2, A2
    vpsrlvq H1, A3, A3
    vpsrlvq H1, A4, A4
    vpsrlvq H1, A5, A5
    vpsrlvq H1, A6, A6
    vpsrlvq H1, A7, A7
    vpsrlvq H1, A8, A8
    vpsrlvq H1, A9, A9

    vpbroadcastq andMask(%rip), AND_MASK
    vpandq AND_MASK, A0, A0
    vpandq AND_MASK, A1, A1
    vpandq AND_MASK, A2, A2
    vpandq AND_MASK, A3, A3
    vpandq AND_MASK, A4, A4
    vpandq AND_MASK, A5, A5
    vpandq AND_MASK, A6, A6
    vpandq AND_MASK, A7, A7
    vpandq AND_MASK, A8, A8
    vpandq AND_MASK, A9, A9
    vpxorq A10, A10, A10
    
    vpbroadcastq 0*64(%rsp), H0
    vpmuludq A0, H0, ACC0
    vpmuludq A1, H0, ACC1
    vpmuludq A2, H0, ACC2
    vpmuludq A3, H0, ACC3
    vpmuludq A4, H0, ACC4
    vpmuludq A5, H0, ACC5
    vpmuludq A6, H0, ACC6
    vpmuludq A7, H0, ACC7
    vpmuludq A8, H0, ACC8
    vpmuludq A9, H0, ACC9
    vpbroadcastq 1*64(%rsp), H0
    IFMA A0, H0, ACC1
    IFMA A1, H0, ACC2
    IFMA A2, H0, ACC3
    IFMA A3, H0, ACC4
    IFMA A4, H0, ACC5
    IFMA A5, H0, ACC6
    IFMA A6, H0, ACC7
    IFMA A7, H0, ACC8
    IFMA A8, H0, ACC9
    vpmuludq A9, H0, ACC10
    vpbroadcastq 2*64(%rsp), H0
    IFMA A0, H0, ACC2
    IFMA A1, H0, ACC3
    IFMA A2, H0, ACC4
    IFMA A3, H0, ACC5
    IFMA A4, H0, ACC6
    IFMA A5, H0, ACC7
    IFMA A6, H0, ACC8
    IFMA A7, H0, ACC9
    IFMA A8, H0, ACC10
    vpmuludq A9, H0, ACC11
    vpbroadcastq 3*64(%rsp), H0
    IFMA A0, H0, ACC3
    IFMA A1, H0, ACC4
    IFMA A2, H0, ACC5
    IFMA A3, H0, ACC6
    IFMA A4, H0, ACC7
    IFMA A5, H0, ACC8
    IFMA A6, H0, ACC9
    IFMA A7, H0, ACC10
    IFMA A8, H0, ACC11
    vpmuludq A9, H0, ACC12
    vpbroadcastq 4*64(%rsp), H0
    IFMA A0, H0, ACC4
    IFMA A1, H0, ACC5
    IFMA A2, H0, ACC6
    IFMA A3, H0, ACC7
    IFMA A4, H0, ACC8
    IFMA A5, H0, ACC9
    IFMA A6, H0, ACC10
    IFMA A7, H0, ACC11
    IFMA A8, H0, ACC12
    vpmuludq A9, H0, ACC13
    vpbroadcastq 5*64(%rsp), H0
    IFMA A0, H0, ACC5
    IFMA A1, H0, ACC6
    IFMA A2, H0, ACC7
    IFMA A3, H0, ACC8
    IFMA A4, H0, ACC9
    IFMA A5, H0, ACC10
    IFMA A6, H0, ACC11
    IFMA A7, H0, ACC12
    IFMA A8, H0, ACC13
    vpmuludq A9, H0, ACC14
    vpbroadcastq 6*64(%rsp), H0
    IFMA A0, H0, ACC6
    IFMA A1, H0, ACC7
    IFMA A2, H0, ACC8
    IFMA A3, H0, ACC9
    IFMA A4, H0, ACC10
    IFMA A5, H0, ACC11
    IFMA A6, H0, ACC12
    IFMA A7, H0, ACC13
    IFMA A8, H0, ACC14
    vpmuludq A9, H0, ACC15
    vpbroadcastq 7*64(%rsp), H0
    IFMA A0, H0, ACC7
    IFMA A1, H0, ACC8
    IFMA A2, H0, ACC9
    IFMA A3, H0, ACC10
    IFMA A4, H0, ACC11
    IFMA A5, H0, ACC12
    IFMA A6, H0, ACC13
    IFMA A7, H0, ACC14
    IFMA A8, H0, ACC15
    vpmuludq A9, H0, ACC16
    vpbroadcastq 8*64(%rsp), H0
    IFMA A0, H0, ACC8
    IFMA A1, H0, ACC9
    IFMA A2, H0, ACC10
    IFMA A3, H0, ACC11
    IFMA A4, H0, ACC12
    IFMA A5, H0, ACC13
    IFMA A6, H0, ACC14
    IFMA A7, H0, ACC15
    IFMA A8, H0, ACC16
    vpmuludq A9, H0, ACC17
    vpbroadcastq 9*64(%rsp), H0
    IFMA A0, H0, ACC9
    IFMA A1, H0, ACC10
    IFMA A2, H0, ACC11
    IFMA A3, H0, ACC12
    IFMA A4, H0, ACC13
    IFMA A5, H0, ACC14
    IFMA A6, H0, ACC15
    IFMA A7, H0, ACC16
    IFMA A8, H0, ACC17
    vpmuludq A9, H0, ACC18
    # We need to align the accumulator, but that will create dependency
    # on the output of the previous operation
    # Instead we align A. However A will overflow after 6 such iterations,
    # this is when we switch to a slightly different loop
    vpxorq ZERO, ZERO, ZERO
    valignq  $7, A8, A9, A9
    valignq  $7, A7, A8, A8
    valignq  $7, A6, A7, A7
    valignq  $7, A5, A6, A6
    valignq  $7, A4, A5, A5
    valignq  $7, A3, A4, A4
    valignq  $7, A2, A3, A3
    valignq  $7, A1, A2, A2
    valignq  $7, A0, A1, A1
    valignq  $7, ZERO, A0, A0
    leaq 8(%rsp), %rsp
    
    vpbroadcastq 9*64(%rsp), H0
    IFMA A0, H0, ACC9
    IFMA A1, H0, ACC10
    IFMA A2, H0, ACC11
    IFMA A3, H0, ACC12
    IFMA A4, H0, ACC13
    IFMA A5, H0, ACC14
    IFMA A6, H0, ACC15
    IFMA A7, H0, ACC16
    IFMA A8, H0, ACC17
    IFMA A9, H0, ACC18

    # The classic approach is to multiply by a single digit of B
    # each iteration, however we prefer to multiply by all digits
    # with 8-digit interval, while the registers are aligned, and then
    # shift.
    mov $6, itr1
1:
        # Multiply the correctly aligned values
        vpbroadcastq 0*64(%rsp), H0
        IFMA A0, H0, ACC0
        IFMA A1, H0, ACC1
        IFMA A2, H0, ACC2
        IFMA A3, H0, ACC3
        IFMA A4, H0, ACC4
        IFMA A5, H0, ACC5
        IFMA A6, H0, ACC6
        IFMA A7, H0, ACC7
        IFMA A8, H0, ACC8
        IFMA A9, H0, ACC9
        vpbroadcastq 1*64(%rsp), H0
        IFMA A0, H0, ACC1
        IFMA A1, H0, ACC2
        IFMA A2, H0, ACC3
        IFMA A3, H0, ACC4
        IFMA A4, H0, ACC5
        IFMA A5, H0, ACC6
        IFMA A6, H0, ACC7
        IFMA A7, H0, ACC8
        IFMA A8, H0, ACC9
        IFMA A9, H0, ACC10
        vpbroadcastq 2*64(%rsp), H0
        IFMA A0, H0, ACC2
        IFMA A1, H0, ACC3
        IFMA A2, H0, ACC4
        IFMA A3, H0, ACC5
        IFMA A4, H0, ACC6
        IFMA A5, H0, ACC7
        IFMA A6, H0, ACC8
        IFMA A7, H0, ACC9
        IFMA A8, H0, ACC10
        IFMA A9, H0, ACC11
        vpbroadcastq 3*64(%rsp), H0
        IFMA A0, H0, ACC3
        IFMA A1, H0, ACC4
        IFMA A2, H0, ACC5
        IFMA A3, H0, ACC6
        IFMA A4, H0, ACC7
        IFMA A5, H0, ACC8
        IFMA A6, H0, ACC9
        IFMA A7, H0, ACC10
        IFMA A8, H0, ACC11
        IFMA A9, H0, ACC12
        vpbroadcastq 4*64(%rsp), H0
        IFMA A0, H0, ACC4
        IFMA A1, H0, ACC5
        IFMA A2, H0, ACC6
        IFMA A3, H0, ACC7
        IFMA A4, H0, ACC8
        IFMA A5, H0, ACC9
        IFMA A6, H0, ACC10
        IFMA A7, H0, ACC11
        IFMA A8, H0, ACC12
        IFMA A9, H0, ACC13
        vpbroadcastq 5*64(%rsp), H0
        IFMA A0, H0, ACC5
        IFMA A1, H0, ACC6
        IFMA A2, H0, ACC7
        IFMA A3, H0, ACC8
        IFMA A4, H0, ACC9
        IFMA A5, H0, ACC10
        IFMA A6, H0, ACC11
        IFMA A7, H0, ACC12
        IFMA A8, H0, ACC13
        IFMA A9, H0, ACC14
        vpbroadcastq 6*64(%rsp), H0
        IFMA A0, H0, ACC6
        IFMA A1, H0, ACC7
        IFMA A2, H0, ACC8
        IFMA A3, H0, ACC9
        IFMA A4, H0, ACC10
        IFMA A5, H0, ACC11
        IFMA A6, H0, ACC12
        IFMA A7, H0, ACC13
        IFMA A8, H0, ACC14
        IFMA A9, H0, ACC15
        vpbroadcastq 7*64(%rsp), H0
        IFMA A0, H0, ACC7
        IFMA A1, H0, ACC8
        IFMA A2, H0, ACC9
        IFMA A3, H0, ACC10
        IFMA A4, H0, ACC11
        IFMA A5, H0, ACC12
        IFMA A6, H0, ACC13
        IFMA A7, H0, ACC14
        IFMA A8, H0, ACC15
        IFMA A9, H0, ACC16
        vpbroadcastq 8*64(%rsp), H0
        IFMA A0, H0, ACC8
        IFMA A1, H0, ACC9
        IFMA A2, H0, ACC10
        IFMA A3, H0, ACC11
        IFMA A4, H0, ACC12
        IFMA A5, H0, ACC13
        IFMA A6, H0, ACC14
        IFMA A7, H0, ACC15
        IFMA A8, H0, ACC16
        IFMA A9, H0, ACC17

        dec itr1
        jz  3f

        # We need to align the accumulator, but that will create dependency
        # on the output of the previous operation
        # Instead we align A. However A will overflow after 6 such iterations,
        # this is when we switch to a slightly different loop

        vpxorq ZERO, ZERO, ZERO
        valignq  $7, A8, A9, A9
        valignq  $7, A7, A8, A8
        valignq  $7, A6, A7, A7
        valignq  $7, A5, A6, A6
        valignq  $7, A4, A5, A5
        valignq  $7, A3, A4, A4
        valignq  $7, A2, A3, A3
        valignq  $7, A1, A2, A2
        valignq  $7, A0, A1, A1
        valignq  $7, ZERO, A0, A0
        leaq 8(%rsp), %rsp

    jmp 1b

3:
    vpxorq ZERO, ZERO, ZERO
    valignq  $7, A9, A10, A10
    valignq  $7, A8, A9, A9
    valignq  $7, A7, A8, A8
    valignq  $7, A6, A7, A7
    valignq  $7, A5, A6, A6
    valignq  $7, A4, A5, A5
    valignq  $7, A3, A4, A4
    valignq  $7, A2, A3, A3
    valignq  $7, A1, A2, A2
    valignq  $7, A0, A1, A1
    valignq  $7, ZERO, A0, A0
    leaq 8(%rsp), %rsp

    vpbroadcastq 0*64(%rsp), H0
    IFMA A0, H0, ACC0
    IFMA A1, H0, ACC1
    IFMA A2, H0, ACC2
    IFMA A3, H0, ACC3
    IFMA A4, H0, ACC4
    IFMA A5, H0, ACC5
    IFMA A6, H0, ACC6
    IFMA A7, H0, ACC7
    IFMA A8, H0, ACC8
    IFMA A9, H0, ACC9
    IFMA A10, H0, ACC10
    vpbroadcastq 1*64(%rsp), H0
    IFMA A0, H0, ACC1
    IFMA A1, H0, ACC2
    IFMA A2, H0, ACC3
    IFMA A3, H0, ACC4
    IFMA A4, H0, ACC5
    IFMA A5, H0, ACC6
    IFMA A6, H0, ACC7
    IFMA A7, H0, ACC8
    IFMA A8, H0, ACC9
    IFMA A9, H0, ACC10
    IFMA A10, H0, ACC11
    vpbroadcastq 2*64(%rsp), H0
    IFMA A0, H0, ACC2
    IFMA A1, H0, ACC3
    IFMA A2, H0, ACC4
    IFMA A3, H0, ACC5
    IFMA A4, H0, ACC6
    IFMA A5, H0, ACC7
    IFMA A6, H0, ACC8
    IFMA A7, H0, ACC9
    IFMA A8, H0, ACC10
    IFMA A9, H0, ACC11
    IFMA A10, H0, ACC12
    vpbroadcastq 3*64(%rsp), H0
    IFMA A0, H0, ACC3
    IFMA A1, H0, ACC4
    IFMA A2, H0, ACC5
    IFMA A3, H0, ACC6
    IFMA A4, H0, ACC7
    IFMA A5, H0, ACC8
    IFMA A6, H0, ACC9
    IFMA A7, H0, ACC10
    IFMA A8, H0, ACC11
    IFMA A9, H0, ACC12
    IFMA A10, H0, ACC13
    vpbroadcastq 4*64(%rsp), H0
    IFMA A0, H0, ACC4
    IFMA A1, H0, ACC5
    IFMA A2, H0, ACC6
    IFMA A3, H0, ACC7
    IFMA A4, H0, ACC8
    IFMA A5, H0, ACC9
    IFMA A6, H0, ACC10
    IFMA A7, H0, ACC11
    IFMA A8, H0, ACC12
    IFMA A9, H0, ACC13
    IFMA A10, H0, ACC14
    vpbroadcastq 5*64(%rsp), H0
    IFMA A0, H0, ACC5
    IFMA A1, H0, ACC6
    IFMA A2, H0, ACC7
    IFMA A3, H0, ACC8
    IFMA A4, H0, ACC9
    IFMA A5, H0, ACC10
    IFMA A6, H0, ACC11
    IFMA A7, H0, ACC12
    IFMA A8, H0, ACC13
    IFMA A9, H0, ACC14
    IFMA A10, H0, ACC15
    vpbroadcastq 6*64(%rsp), H0
    IFMA A0, H0, ACC6
    IFMA A1, H0, ACC7
    IFMA A2, H0, ACC8
    IFMA A3, H0, ACC9
    IFMA A4, H0, ACC10
    IFMA A5, H0, ACC11
    IFMA A6, H0, ACC12
    IFMA A7, H0, ACC13
    IFMA A8, H0, ACC14
    IFMA A9, H0, ACC15
    IFMA A10, H0, ACC16
    vpbroadcastq 7*64(%rsp), H0
    IFMA A0, H0, ACC7
    IFMA A1, H0, ACC8
    IFMA A2, H0, ACC9
    IFMA A3, H0, ACC10
    IFMA A4, H0, ACC11
    IFMA A5, H0, ACC12
    IFMA A6, H0, ACC13
    IFMA A7, H0, ACC14
    IFMA A8, H0, ACC15
    IFMA A9, H0, ACC16
    IFMA A10, H0, ACC17
    vpbroadcastq 8*64(%rsp), H0
    IFMA A0, H0, ACC8
    IFMA A1, H0, ACC9
    IFMA A2, H0, ACC10
    IFMA A3, H0, ACC11
    IFMA A4, H0, ACC12
    IFMA A5, H0, ACC13
    IFMA A6, H0, ACC14
    IFMA A7, H0, ACC15
    IFMA A8, H0, ACC16
    IFMA A9, H0, ACC17
    IFMA A10, H0, ACC18

    vpbroadcastq andMask(%rip), AND_MASK
    vpxorq ZERO, ZERO, ZERO
    mov $2, itr1
1:
    vpsrlq $28, ACC0, A0
    vpsrlq $28, ACC1, A1
    vpsrlq $28, ACC2, A2
    vpsrlq $28, ACC3, A3
    vpsrlq $28, ACC4, A4
    vpsrlq $28, ACC5, A5
    vpsrlq $28, ACC6, A6
    vpsrlq $28, ACC7, A7
    vpsrlq $28, ACC8, A8
    vpsrlq $28, ACC9, A9
    vpxorq A10, A10, A10
    
    vpandq AND_MASK, ACC0, ACC0
    vpandq AND_MASK, ACC1, ACC1
    vpandq AND_MASK, ACC2, ACC2
    vpandq AND_MASK, ACC3, ACC3
    vpandq AND_MASK, ACC4, ACC4
    vpandq AND_MASK, ACC5, ACC5
    vpandq AND_MASK, ACC6, ACC6
    vpandq AND_MASK, ACC7, ACC7
    vpandq AND_MASK, ACC8, ACC8
    vpandq AND_MASK, ACC9, ACC9

    valignq $7, A9, A10, A10
    valignq $7, A8, A9, A9
    valignq $7, A7, A8, A8
    valignq $7, A6, A7, A7
    valignq $7, A5, A6, A6
    valignq $7, A4, A5, A5
    valignq $7, A3, A4, A4
    valignq $7, A2, A3, A3
    valignq $7, A1, A2, A2
    valignq $7, A0, A1, A1
    valignq $7, ZERO, A0, A0

    vpaddq A0, ACC0, ACC0
    vpaddq A1, ACC1, ACC1
    vpaddq A2, ACC2, ACC2
    vpaddq A3, ACC3, ACC3
    vpaddq A4, ACC4, ACC4
    vpaddq A5, ACC5, ACC5
    vpaddq A6, ACC6, ACC6
    vpaddq A7, ACC7, ACC7
    vpaddq A8, ACC8, ACC8
    vpaddq A9, ACC9, ACC9

    vpsrlq $28, ACC10, A0
    vpsrlq $28, ACC11, A1
    vpsrlq $28, ACC12, A2
    vpsrlq $28, ACC13, A3
    vpsrlq $28, ACC14, A4
    vpsrlq $28, ACC15, A5
    vpsrlq $28, ACC16, A6
    vpsrlq $28, ACC17, A7
    vpsrlq $28, ACC18, A8

    vpandq AND_MASK, ACC10, ACC10
    vpandq AND_MASK, ACC11, ACC11
    vpandq AND_MASK, ACC12, ACC12
    vpandq AND_MASK, ACC13, ACC13
    vpandq AND_MASK, ACC14, ACC14
    vpandq AND_MASK, ACC15, ACC15
    vpandq AND_MASK, ACC16, ACC16
    vpandq AND_MASK, ACC17, ACC17
    vpandq AND_MASK, ACC18, ACC18

    valignq $7, A7, A8, A8
    valignq $7, A6, A7, A7
    valignq $7, A5, A6, A6
    valignq $7, A4, A5, A5
    valignq $7, A3, A4, A4
    valignq $7, A2, A3, A3
    valignq $7, A1, A2, A2
    valignq $7, A0, A1, A1
    valignq $7, ZERO, A0, A0
    vpxorq A10, A0, A0

    vpaddq A0, ACC10, ACC10
    vpaddq A1, ACC11, ACC11
    vpaddq A2, ACC12, ACC12
    vpaddq A3, ACC13, ACC13
    vpaddq A4, ACC14, ACC14
    vpaddq A5, ACC15, ACC15
    vpaddq A6, ACC16, ACC16
    vpaddq A7, ACC17, ACC17
    vpaddq A8, ACC18, ACC18

    dec itr1
    jnz 1b

    vpsubq one(%rip){1to8}, ZERO, AND_MASK
    mov $0x8000, %eax
    kmovd %eax, %k1

    valignq $7, ACC1, ZERO, A0
    valignq $7, ACC3, ZERO, A1
    valignq $7, ACC5, ZERO, A2
    valignq $7, ACC7, ZERO, A3
    valignq $7, ACC9, ZERO, A4
    valignq $7, ACC11, ZERO, A5
    valignq $7, ACC13, ZERO, A6
    valignq $7, ACC15, ZERO, A7
    valignq $7, ACC17, ZERO, A8
    vpsrlq $28, A0, A0
    vpsrlq $28, A1, A1
    vpsrlq $28, A2, A2
    vpsrlq $28, A3, A3
    vpsrlq $28, A4, A4
    vpsrlq $28, A5, A5
    vpsrlq $28, A6, A6
    vpsrlq $28, A7, A7
    vpsrlq $28, A8, A8
    vpaddq A0, ACC2, ACC2
    vpaddq A1, ACC4, ACC4
    vpaddq A2, ACC6, ACC6
    vpaddq A3, ACC8, ACC8
    vpaddq A4, ACC10, ACC10
    vpaddq A5, ACC12, ACC12
    vpaddq A6, ACC14, ACC14
    vpaddq A7, ACC16, ACC16
    vpaddq A8, ACC18, ACC18
    
    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vmovdqa64 fixMask2(%rip), A2
    vpermi2d ACC1, ACC0, A0
    vpermi2w ACC1, ACC0, A1
    vpermt2d ACC1, A2, ACC0
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC0, ACC0
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC0, ACC0

    mov $7, %ecx
    vpcmpuq $1, A0, ACC0, %k3
    vpcmpuq $0, AND_MASK, ACC0, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC0, ACC0{%k3}

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC3, ACC2, A0
    vpermi2w ACC3, ACC2, A1
    vpermt2d ACC3, A2, ACC2
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC2, ACC2
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC2, ACC2


    mov $0x80, %eax
    kmovd %eax, %k2

    vpcmpuq $1, A0, ACC2, %k3
    vpcmpuq $0, AND_MASK, ACC2, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC2, ACC2{%k3}

    valignq $1, ACC2, ACC2, ACC0{%k2}
    valignq $1, ACC2, ZERO, ACC2

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC5, ACC4, A0
    vpermi2w ACC5, ACC4, A1
    vpermt2d ACC5, A2, ACC4
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC4, ACC4
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC4, ACC4
    mov $0xc0, %eax
    kmovd %eax, %k2

    vpcmpuq $1, A0, ACC4, %k3
    vpcmpuq $0, AND_MASK, ACC4, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC4, ACC4{%k3}

    valignq $2, ACC4, ACC4, ACC2{%k2}
    valignq $2, ACC4, ZERO, ACC4

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC7, ACC6, A0
    vpermi2w ACC7, ACC6, A1
    vpermt2d ACC7, A2, ACC6
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC6, ACC6
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC6, ACC6
    mov $0xe0, %eax
    kmovd %eax, %k2

    vpcmpuq $1, A0, ACC6, %k3
    vpcmpuq $0, AND_MASK, ACC6, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC6, ACC6{%k3}
    valignq $3, ACC6, ACC6, ACC4{%k2}
    valignq $3, ACC6, ZERO, ACC6

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC9, ACC8, A0
    vpermi2w ACC9, ACC8, A1
    vpermt2d ACC9, A2, ACC8
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC8, ACC8
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC8, ACC8

    vpcmpuq $1, A0, ACC8, %k3
    vpcmpuq $0, AND_MASK, ACC8, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC8, ACC8{%k3}

    mov $0xf0, %eax
    kmovd %eax, %k2
    valignq $4, ACC8, ACC8, ACC6{%k2}
    valignq $4, ACC8, ZERO, ACC8

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC11, ACC10, A0
    vpermi2w ACC11, ACC10, A1
    vpermt2d ACC11, A2, ACC10
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC10, ACC10
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC10, ACC10

    vpcmpuq $1, A0, ACC10, %k3
    vpcmpuq $0, AND_MASK, ACC10, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC10, ACC10{%k3}

    mov $0xf8, %eax
    kmovd %eax, %k2
    valignq $5, ACC10, ACC10, ACC8{%k2}
    valignq $5, ACC10, ZERO, ACC10

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC13, ACC12, A0
    vpermi2w ACC13, ACC12, A1
    vpermt2d ACC13, A2, ACC12
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC12, ACC12
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC12, ACC12

    vpcmpuq $1, A0, ACC12, %k3
    vpcmpuq $0, AND_MASK, ACC12, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC12, ACC12{%k3}

    mov $0xfc, %eax
    kmovd %eax, %k2
    valignq $6, ACC12, ACC12, ACC10{%k2}
    valignq $6, ACC12, ZERO, ACC12

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC15, ACC14, A0
    vpermi2w ACC15, ACC14, A1
    vpermt2d ACC15, A2, ACC14
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC14, ACC14
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC14, ACC14

    vpcmpuq $1, A0, ACC14, %k3
    vpcmpuq $0, AND_MASK, ACC14, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC14, ACC14{%k3}

    mov $0xfe, %eax
    kmovd %eax, %k2
    valignq $7, ACC14, ACC14, ACC12{%k2}

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC17, ACC16, A0
    vpermi2w ACC17, ACC16, A1
    vpermt2d ACC17, A2, ACC16
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC16, ACC16
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC16, ACC14

    vpcmpuq $1, A0, ACC14, %k3
    vpcmpuq $0, AND_MASK, ACC14, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC14, ACC14{%k3}

    vmovdqa64 fixMask0(%rip), A0
    vmovdqa64 fixMask1(%rip), A1
    vpermi2d ACC18, ACC18, A0
    vpermi2w ACC18, ACC18, A1
    vpermt2d ACC18, A2, ACC18
    vpsrlvq fixShift0(%rip), A0, A0
    vpsllvq fixShift1(%rip), A1, A1
    vpsllvq fixShift2(%rip), ACC18, ACC18
    vpsllw $8, A1, A1{%k1}
    vpaddq A1, A0, A0
    vpaddq A0, ACC18, ACC16

    vpcmpuq $1, A0, ACC16, %k3
    vpcmpuq $0, AND_MASK, ACC16, %k4
    kmovb %k3, %eax
    kmovb %k4, %r8d
    add %al, %al
    add %dl, %al
    add %r8b, %al
    shrx %ecx, %eax, %edx
    xor %r8b, %al
    kmovb %eax, %k3
    vpsubq AND_MASK, ACC16, ACC16{%k3}

    mov $0x80, %eax
    kmovd %eax, %k2
    valignq $1, ACC16, ACC16, ACC14{%k2}

    vmovdqu64 ACC0, 64*0(res)
    vmovdqu64 ACC2, 64*1(res)
    vmovdqu64 ACC4, 64*2(res)
    vmovdqu64 ACC6, 64*3(res)
    vmovdqu64 ACC8, 64*4(res)
    vmovdqu64 ACC10, 64*5(res)
    vmovdqu64 ACC12, 64*6(res)
    vmovdqu64 ACC14, 64*7(res)
     
    mov %rbp, %rsp
    pop %rbp
    ret
.size mul2048_avx512, .-mul2048_avx512
