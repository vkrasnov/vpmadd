/*
 *  Multiply two 1024-bit numbers using AVX512F instructions
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
# Masks to convert 2^64->2^29
permMask:
.short 0, 1, 0, 0,  1, 2, 3, 0,  3, 4, 5, 0,  5, 6, 7, 0
.short 7, 8, 9, 0,  9,10, 0, 0, 10,11,12, 0, 12,13,14, 0
shiftMask:
.quad  0,13,10, 7, 4, 1, 14,11

# Masks to convert 2^29->2^64
.align 64
fixMask0:
.long  0, 1, 4, 1, 8, 1,12, 1,16, 1,22, 1,26, 1,30, 1
fixMask1:
.short  4, 5, 3, 3
.short 12,13, 3, 3
.short 20,21, 3, 3
.short 28,29, 3, 3
.short 36,37, 3,44
.short 48,49, 3, 3
.short 56,57, 3, 3
.short 34,35, 3, 3
fixMask2:
.long  4, 1, 8, 1,12, 1,16, 1,20, 1,26, 1,30, 1,19, 1
fixShift0:
.quad  0, 6,12,18,24, 1, 7,13
fixShift1:
.quad 29,23,17,11, 5,28,22,16
fixShift2:
.quad 58,52,46,40,34,57,51,45

fixMask3:
.long  2, 1, 6, 1,12, 1,16, 1,20, 1,24, 1,28, 1,19, 1
fixMask4:
.short  8, 9, 3, 3
.short 16,17, 3,24
.short 28,29, 3, 3
.short 36,37, 3, 3
.short 44,45, 3, 3
.short 52,53, 3, 3
.short 60,61, 3,38
.short 42,43, 3, 3
fixMask5:
.long  6, 1,10, 1,16, 1,20, 1,24, 1,28, 1,17, 1,23, 1
fixShift3:
.quad 19,25, 2, 8,14,20,26, 3
fixShift4:
.quad 10, 4,27,21,15, 9, 3,26
fixShift5:
.quad 39,33,56,50,44,38,32,55

fixMask6:
.long  6, 1,10, 1,14, 1,18, 1,24, 1,28, 1,17, 1,21, 1
fixMask7:
.short 16,17, 3, 3
.short 24,25, 3, 3
.short 32,33, 3, 3
.short 40,41, 3,48
.short 52,53, 3, 3
.short 60,61, 3, 3
.short 38,39, 3, 3
.short 46,47, 3, 3
fixMask8:
.long 10, 1,14, 1,18, 1,22, 1,28, 1,17, 1,21, 1,25, 1
fixShift6:
.quad  9,15,21,27, 4,10,16,22
fixShift7:
.quad 20,14, 8, 2,25,19,13, 7
fixShift8:
.quad 49,43,37,31,54,48,42,36

fixMask9:
.long  8, 1,14, 1,18, 1,22, 1,26, 1,30, 1,21, 1,25, 1
fixMask10:
.short 20,21, 3,28
.short 32,33, 3, 3
.short 40,41, 3, 3
.short 48,49, 3, 3
.short 56,57, 3, 3
.short 34,35, 3,42
.short 46,47, 3, 3
.short 54,55, 3, 3
fixMask11:
.long 12, 1,18, 1,22, 1,26, 1,30, 1,19, 1,25, 1,29, 1
fixShift9:
.quad 28, 5,11,17,23,29, 6,12
fixShift10:
.quad  1,24,18,12, 6, 0,23,17
fixShift11:
.quad 30,53,47,41,35,29,52,46

# Mask for the bottom 29 bits
andMask:
.quad 0x1FFFFFFF
# The constant 1
one:
.quad 1

# The result is 2048 bit. ceil(2048/29) = 71. ceil(40/8) = 9.
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
# The inputs are 1024 bit. ceil(1024/29) = 36. ceil(36/8) = 5.
.set A0, %zmm9
.set A1, %zmm10
.set A2, %zmm11
.set A3, %zmm12
.set A4, %zmm13
.set A5, %zmm14

.set B0, %zmm15
.set B1, %zmm16
.set B2, %zmm17
.set B3, %zmm18
.set B4, %zmm19
# Helper registers
.set ZERO, %zmm20     # always zero
.set IDX, %zmm21      # current index for the permutation
.set ONE, %zmm22      # (uint64_t)1, broadcasted
.set AND_MASK, %zmm23 # for masking the 29 bits of each qword

.set T0, %zmm24
.set T1, %zmm25
.set T2, %zmm26
.set T3, %zmm27
.set T4, %zmm28

.set H0, %zmm29
# To be used only after we are done with A and B
.set T5, A0
.set T6, A1
.set T7, A2
.set T8, A3

.set H1, A4
.set H2, A5
.set H3, B0
.set H4, B1
.set H5, B2
.set H6, B3
.set H7, B4
.set H8, %zmm30

# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %rax
.set itr2, %rcx

# void mul1024_avx512(uint64_t res[32], uint64_t a[16], uint64_t b[16]);
.globl mul1024_avx512
.type mul1024_avx512, @function
mul1024_avx512:

    mov   $0x3f, %ecx
    kmovd %ecx, %k1

    vpxorq ZERO, ZERO, ZERO
    vpxorq IDX, IDX, IDX
    # First we need to convert the input from radix 2^64 to redundant 2^29
    vmovdqa64 permMask(%rip), T0
    vmovdqa64 shiftMask(%rip), T1
    vpbroadcastq andMask(%rip), AND_MASK
    vpbroadcastq one(%rip), ONE
    # Load values with 29-byte intervals and shuffle + shift accordingly
    # First A
    vpermw 29*0(a), T0, A0
    vpermw 29*1(a), T0, A1
    vpermw 29*2(a), T0, A2
    vpermw 29*3(a), T0, A3
    vmovdqu16 29*4(a), A4{%k1}{z}
    vpermw A4, T0, A4

    vpsrlvq T1, A0, A0
    vpsrlvq T1, A1, A1
    vpsrlvq T1, A2, A2
    vpsrlvq T1, A3, A3
    vpsrlvq T1, A4, A4

    vpandq AND_MASK, A0, A0
    vpandq AND_MASK, A1, A1
    vpandq AND_MASK, A2, A2
    vpandq AND_MASK, A3, A3
    vpandq AND_MASK, A4, A4
    vpxorq A5, A5, A5
    # Then B
    vpermw 29*0(b), T0, B0
    vpermw 29*1(b), T0, B1
    vpermw 29*2(b), T0, B2
    vpermw 29*3(b), T0, B3
    vmovdqu16 29*4(b), B4{%k1}{z}
    vpermw B4, T0, B4

    vpsrlvq T1, B0, B0
    vpsrlvq T1, B1, B1
    vpsrlvq T1, B2, B2
    vpsrlvq T1, B3, B3
    vpsrlvq T1, B4, B4

    vpandq AND_MASK, B0, B0
    vpandq AND_MASK, B1, B1
    vpandq AND_MASK, B2, B2
    vpandq AND_MASK, B3, B3
    vpandq AND_MASK, B4, B4
    # Zero the accumulators
    vpxorq ACC0, ACC0, ACC0
    vpxorq ACC1, ACC1, ACC1
    vpxorq ACC2, ACC2, ACC2
    vpxorq ACC3, ACC3, ACC3
    vpxorq ACC4, ACC4, ACC4
    vpxorq ACC5, ACC5, ACC5
    vpxorq ACC6, ACC6, ACC6
    vpxorq ACC7, ACC7, ACC7
    vpxorq ACC8, ACC8, ACC8
    # The classic approach is to multiply by a single digit of B
    # each iteration, however we prefer to multiply by all digits
    # with 8-digit interval, while the registers are aligned, and then
    # shift. We have a total of 36 digits, therefore we multipy A in 8
    # iterations by the following digits:
    # itr 0: 0,8,16,24,32
    # itr 1: 1,9,17,25,33
    # itr 2: 2,10,18,26,34
    # itr 3: 3,11,19,27,35
    # itr 4: 4,12,20,28
    # itr 5: 5,13,21,29
    # itr 6: 6,14,22,30
    # itr 7: 7,15,23,31
    # IDX holds the index of the currently required value
    mov $5, itr1
    mov $4, itr2
1:
        # Get the correct digits into T0, T1 and T2
        vpermq B0, IDX, T0
        vpermq B1, IDX, T1
        vpermq B2, IDX, T2
        vpermq B3, IDX, T3
        vpermq B4, IDX, T4
        vpaddq ONE, IDX, IDX
        # Multiply the correctly aligned values
        vpmuludq A0, T0, H0
        vpaddq H0, ACC0, ACC0
        vpmuludq A1, T0, H0
        vpaddq H0, ACC1, ACC1
        vpmuludq A2, T0, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A3, T0, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A4, T0, H0
        vpaddq H0, ACC4, ACC4

        vpmuludq A0, T1, H0
        vpaddq H0, ACC1, ACC1
        vpmuludq A1, T1, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A2, T1, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A3, T1, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A4, T1, H0
        vpaddq H0, ACC5, ACC5

        vpmuludq A0, T2, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A1, T2, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A2, T2, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A3, T2, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A4, T2, H0
        vpaddq H0, ACC6, ACC6

        vpmuludq A0, T3, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A1, T3, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A2, T3, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A3, T3, H0
        vpaddq H0, ACC6, ACC6
        vpmuludq A4, T3, H0
        vpaddq H0, ACC7, ACC7

        vpmuludq A0, T4, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A1, T4, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A2, T4, H0
        vpaddq H0, ACC6, ACC6
        vpmuludq A3, T4, H0
        vpaddq H0, ACC7, ACC7
        vpmuludq A4, T4, H0
        vpaddq H0, ACC8, ACC8

        dec itr1
        jz  3f
        # We need to align the accumulator, but that will create dependency
        # on the output of the previous operation.
        # Instead we align A (which also has fewer digits).
        # However A will overflow after 4 such iterations,
        # this is when we switch to a slightly different loop
        valignq  $7, A3, A4, A4
        valignq  $7, A2, A3, A3
        valignq  $7, A1, A2, A2
        valignq  $7, A0, A1, A1
        valignq  $7, ZERO, A0, A0

    jmp 1b

2:
        # Get the correct digits into T0 and T1
        # We finished all the digits in B4
        vpermq B0, IDX, T0
        vpermq B1, IDX, T1
        vpermq B2, IDX, T2
        vpermq B3, IDX, T3
        vpaddq ONE, IDX, IDX
        # Multiply the correctly aligned values, since A overflowed we now
        # have more multiplications
        vpmuludq A0, T0, H0
        vpaddq H0, ACC0, ACC0
        vpmuludq A1, T0, H0
        vpaddq H0, ACC1, ACC1
        vpmuludq A2, T0, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A3, T0, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A4, T0, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A5, T0, H0
        vpaddq H0, ACC5, ACC5

        vpmuludq A0, T1, H0
        vpaddq H0, ACC1, ACC1
        vpmuludq A1, T1, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A2, T1, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A3, T1, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A4, T1, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A5, T1, H0
        vpaddq H0, ACC6, ACC6

        vpmuludq A0, T2, H0
        vpaddq H0, ACC2, ACC2
        vpmuludq A1, T2, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A2, T2, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A3, T2, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A4, T2, H0
        vpaddq H0, ACC6, ACC6
        vpmuludq A5, T2, H0
        vpaddq H0, ACC7, ACC7

        vpmuludq A0, T3, H0
        vpaddq H0, ACC3, ACC3
        vpmuludq A1, T3, H0
        vpaddq H0, ACC4, ACC4
        vpmuludq A2, T3, H0
        vpaddq H0, ACC5, ACC5
        vpmuludq A3, T3, H0
        vpaddq H0, ACC6, ACC6
        vpmuludq A4, T3, H0
        vpaddq H0, ACC7, ACC7
        vpmuludq A5, T3, H0
        vpaddq H0, ACC8, ACC8
        # This is the entry point for the second loop
        3:
        valignq  $7, A4, A5, A5
        valignq  $7, A3, A4, A4
        valignq  $7, A2, A3, A3
        valignq  $7, A1, A2, A2
        valignq  $7, A0, A1, A1
        valignq  $7, ZERO, A0, A0
        dec itr2
    jnz 2b

    # Perform two folds of the top bits, for
    # easier recombination.
    vpsrlq $29, ACC0, T0
    vpsrlq $29, ACC1, T1
    vpsrlq $29, ACC2, T2
    vpsrlq $29, ACC3, T3
    vpsrlq $29, ACC4, T4
    vpsrlq $29, ACC5, T5
    vpsrlq $29, ACC6, T6
    vpsrlq $29, ACC7, T7
    vpsrlq $29, ACC8, T8

    vpsrlq $58, ACC0, H0
    vpsrlq $58, ACC1, H1
    vpsrlq $58, ACC2, H2
    vpsrlq $58, ACC3, H3
    vpsrlq $58, ACC4, H4
    vpsrlq $58, ACC5, H5
    vpsrlq $58, ACC6, H6
    vpsrlq $58, ACC7, H7
    vpsrlq $58, ACC8, H8

    vpandq AND_MASK, ACC0, ACC0
    vpandq AND_MASK, ACC1, ACC1
    vpandq AND_MASK, ACC2, ACC2
    vpandq AND_MASK, ACC3, ACC3
    vpandq AND_MASK, ACC4, ACC4
    vpandq AND_MASK, ACC5, ACC5
    vpandq AND_MASK, ACC6, ACC6
    vpandq AND_MASK, ACC7, ACC7
    vpandq AND_MASK, ACC8, ACC8

    vpandq AND_MASK, T0, T0
    vpandq AND_MASK, T1, T1
    vpandq AND_MASK, T2, T2
    vpandq AND_MASK, T3, T3
    vpandq AND_MASK, T4, T4
    vpandq AND_MASK, T5, T5
    vpandq AND_MASK, T6, T6
    vpandq AND_MASK, T7, T7
    vpandq AND_MASK, T8, T8

    valignq $7, T7, T8, T8
    valignq $7, T6, T7, T7
    valignq $7, T5, T6, T6
    valignq $7, T4, T5, T5
    valignq $7, T3, T4, T4
    valignq $7, T2, T3, T3
    valignq $7, T1, T2, T2
    valignq $7, T0, T1, T1
    valignq $7, ZERO, T0, T0

    valignq $6, H7, H8, H8
    valignq $6, H6, H7, H7
    valignq $6, H5, H6, H6
    valignq $6, H4, H5, H5
    valignq $6, H3, H4, H4
    valignq $6, H2, H3, H3
    valignq $6, H1, H2, H2
    valignq $6, H0, H1, H1
    valignq $6, ZERO, H0, H0

    vpaddq T0, ACC0, ACC0
    vpaddq T1, ACC1, ACC1
    vpaddq T2, ACC2, ACC2
    vpaddq T3, ACC3, ACC3
    vpaddq T4, ACC4, ACC4
    vpaddq T5, ACC5, ACC5
    vpaddq T6, ACC6, ACC6
    vpaddq T7, ACC7, ACC7
    vpaddq T8, ACC8, ACC8

    vpaddq H0, ACC0, ACC0
    vpaddq H1, ACC1, ACC1
    vpaddq H2, ACC2, ACC2
    vpaddq H3, ACC3, ACC3
    vpaddq H4, ACC4, ACC4
    vpaddq H5, ACC5, ACC5
    vpaddq H6, ACC6, ACC6
    vpaddq H7, ACC7, ACC7
    vpaddq H8, ACC8, ACC8
    # At this stage the redundant values occupy at most 30bit containers
    #################
    # Recombine bits 0:511
    vmovdqa64 fixMask0(%rip), T0
    vmovdqa64 fixMask1(%rip), T1
    vmovdqa64 fixMask2(%rip), T2
    # Combine ACC2 and ACC1 so we can address more words in the permute
    vpsllq  $32, ACC2, T4
    vpxorq  ACC1, T4, T4
    vpermi2d T4, ACC0, T0
    vpermi2w T4, ACC0, T1
    vpermi2d T4, ACC0, T2
    vpsrlvq fixShift0(%rip), T0, T0
    vpsllvq fixShift1(%rip), T1, T1
    vpsllvq fixShift2(%rip), T2, H0
    mov $0x80000, %eax
    kmovd %eax, %k1
    vpsllw $10, T1, T1{%k1}
    # We can sum T0 + T1 with no carry
    # Carry can occur when we add T2
    vpaddq  T0, T1, ACC0
    #################
    # Recombine bits 512:1023
    vmovdqa64 fixMask3(%rip), T0
    vmovdqa64 fixMask4(%rip), T1
    vmovdqa64 fixMask5(%rip), T2

    vpsllq  $32, ACC4, T4
    vpxorq  ACC3, T4, T4
    vpermi2d T4, ACC2, T0
    vpermi2w T4, ACC2, T1
    vpermi2d T4, ACC2, T2
    vpsrlvq fixShift3(%rip), T0, T0
    vpsllvq fixShift4(%rip), T1, T1
    vpsllvq fixShift5(%rip), T2, H1
    mov $0x8000080, %eax
    kmovd %eax, %k1
    vpsllw $10, T1, T1{%k1}
    # We can sum T0 + T1 with no carry
    # Carry can occur when we add T2
    vpaddq  T0, T1, ACC1
    #################
    # Recombine bits 1024:1535
    vmovdqa64 fixMask6(%rip), T0
    vmovdqa64 fixMask7(%rip), T1
    vmovdqa64 fixMask8(%rip), T2

    vpsllq  $32, ACC6, T4
    vpxorq  ACC5, T4, T4
    vpermi2d T4, ACC4, T0
    vpermi2w T4, ACC4, T1
    vpermi2d T4, ACC4, T2

    vpsrlvq fixShift6(%rip), T0, T0
    vpsllvq fixShift7(%rip), T1, T1
    vpsllvq fixShift8(%rip), T2, H2
    mov $0x8000, %eax
    kmovd %eax, %k1
    vpsllw $10, T1, T1{%k1}
    # We can sum T0 + T1 with no carry
    # Carry can occur when we add T2
    vpaddq  T0, T1, ACC2
    #################
    # Recombine bits 1536:2047
    vmovdqa64 fixMask9(%rip), T0
    vmovdqa64 fixMask10(%rip), T1
    vmovdqa64 fixMask11(%rip), T2

    vpsllq  $32, ACC8, T4
    vpxorq  ACC7, T4, T4
    vpermi2d T4, ACC6, T0
    vpermi2w T4, ACC6, T1
    vpermi2d T4, ACC6, T2

    vpsrlvq fixShift9(%rip), T0, T0
    vpsllvq fixShift10(%rip), T1, T1
    vpsllvq fixShift11(%rip), T2, H3
    mov $0x800008, %eax
    kmovd %eax, %k1
    vpsllw $10, T1, T1{%k1}
    # We can sum T0 + T1 with no carry
    # Carry can occur when we add T2
    vpaddq  T0, T1, ACC3
    #################
    # Add and propagate carry
    vpaddq H0, ACC0, ACC0
    vpaddq H1, ACC1, ACC1
    vpaddq H2, ACC2, ACC2
    vpaddq H3, ACC3, ACC3

    vpsubq ONE, ZERO, AND_MASK

    vpcmpuq $1, H0, ACC0, %k1
    vpcmpuq $1, H1, ACC1, %k2
    vpcmpuq $1, H2, ACC2, %k3
    vpcmpuq $1, H3, ACC3, %k4

    kmovb %k1, %eax
    kmovb %k2, %ecx
    kmovb %k3, %edx
    kmovb %k4, %esi

    add %al,  %al
    adc %cl,  %cl
    adc %dl,  %dl
    adc %sil, %sil

    vpcmpuq $0, AND_MASK, ACC0, %k1
    vpcmpuq $0, AND_MASK, ACC1, %k2
    vpcmpuq $0, AND_MASK, ACC2, %k3
    vpcmpuq $0, AND_MASK, ACC3, %k4

    kmovb %k1, %r8d
    kmovb %k2, %r9d
    kmovb %k3, %r10d
    kmovb %k4, %r11d

    add %r8b,  %al
    adc %r9b,  %cl
    adc %r10b, %dl
    adc %r11b, %sil

    xor %r8b, %al
    xor %r9b, %cl
    xor %r10b,%dl
    xor %r11b, %sil

    kmovb %eax, %k1
    kmovb %ecx, %k2
    kmovb %edx, %k3
    kmovb %esi, %k4

    vpsubq AND_MASK, ACC0, ACC0{%k1}
    vpsubq AND_MASK, ACC1, ACC1{%k2}
    vpsubq AND_MASK, ACC2, ACC2{%k3}
    vpsubq AND_MASK, ACC3, ACC3{%k4}

    vmovdqu64 ACC0, 64*0(res)
    vmovdqu64 ACC1, 64*1(res)
    vmovdqu64 ACC2, 64*2(res)
    vmovdqu64 ACC3, 64*3(res)
    ret
.size mul1024_avx512, .-mul1024_avx512
