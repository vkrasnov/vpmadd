/*
 *  Multiply two 1024-bit numbers using AVX512IFMA instructions
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
.short  0, 1, 2, 3,   3, 4, 5, 6,   6, 7, 8, 9,   9,10,11,12
.short 13,14,15,16,  16,17,18,19,  19,20,21,22,  22,23,24,25
shiftMask:
.quad  0,4,8,12,0,4,8,12
# Mask to convert 2^52->2^64
.align 64
fixMask0:
.byte  0, 1, 2, 3, 4, 5, 6, 7
.byte  7, 9,10,11,12,13,14,15
.byte  7, 7, 7,19,20,21,22,23
.byte  7, 7, 7, 7,28,29,30,31
.byte 38,39, 7, 7, 7, 7, 7,48
.byte  7,49,50,51,52,53,54,55
.byte  7, 7,58,59,60,61,62,63
.byte  7, 7, 7, 7,68,69,70,71
fixMask1:
.byte  8, 9, 7, 7, 7, 7, 7, 7
.byte 16,17,18, 7, 7, 7, 7, 7
.byte 24,25,26,27,28, 7, 7, 7
.byte 32,33,34,35,36,37, 7, 7
.byte 40,41,42,43,44,45,46,47
.byte 47, 7, 7, 7, 7,56,57,58
.byte 64,65,66,67, 7, 7, 7, 7
.byte 72,73,74,75,76,77, 7, 7
fixShift0:
.quad 0,12,24,36, 0, 8,20,32
fixShift1:
.quad 52,40,28,16,4, 4,32,20

fixMask2:
.byte 13,14,15, 7, 7, 7, 7,24
.byte 24,25,26,27,28,29,30,31
.byte 34,35,36,37,38,39, 7, 7
.byte 43,44,45,46,47, 7, 7, 7
.byte 53,54,55, 7, 7, 7, 7, 7
.byte 62,63, 7, 7, 7, 7,72,73
.byte 73,74,75,76,77,78,79, 7
.byte 83,84,85,86,87, 7, 7, 7
fixMask3:
.byte  7,16,17,18,19,20,21,22
.byte 23, 7, 7, 7, 7, 7,32,33
.byte 40,41,42,43, 7, 7, 7, 7
.byte  7, 7, 7,48,49,50,51,52
.byte 56,57,58,59,60,61,62, 7
.byte 64,65,66,67,68,69,70,71
.byte  7, 7, 7, 7, 7,80,81,82
.byte  7, 7, 7,88,89,90,91,92
fixShift2:
.quad  4, 4, 0, 4, 0, 4, 4, 0
fixShift3:
.quad  0, 0,36, 0,12, 0, 0, 4

fixMask4:
.byte  28, 29, 30, 31,127,127,127,127
.byte  38, 39,127,127,127,127,127, 48
.byte  49, 50, 51, 52, 53, 54, 55,127
.byte  58, 59, 60, 61, 62, 63,127,127
.byte  68, 69, 70, 71,127,127,127,127
.byte  77, 78, 79,127,127,127,127, 88
.byte  88, 89, 90, 91, 92, 93, 94, 95
.byte  98, 99,100,101,102,103,127,127
fixMask5:
.byte  32, 33, 34, 35, 36, 37,127,127
.byte  40, 41, 42, 43, 44, 45, 46, 47
.byte  56, 57, 58,127,127,127,127,127
.byte  64, 65, 66, 67,127,127,127,127
.byte  72, 73, 74, 75, 76, 77,127,127
.byte  80, 81, 82, 83, 84, 85, 86,127
.byte  87,127,127,127,127,127, 96, 97
.byte 104,105,106,107,127,127,127,127
fixShift4:
.quad  4, 0, 0, 4, 0, 4, 4, 0
fixShift5:
.quad 16, 4,44,32,20, 8, 0,36

fixMask6:
.byte  43, 44, 45, 46, 47,127,127,127
.byte  53, 54, 55,127,127,127,127,127
.byte  64, 65, 66, 67, 68, 69, 70, 71
.byte  73, 74, 75, 76, 77, 78, 79,127
.byte  83, 84, 85, 86, 87,127,127,127
.byte  92, 93, 94, 95,127,127,127,127
.byte 102,103,127,127,127,127,127,112
.byte 113,114,115,116,117,118,119,127
fixMask7:
.byte  48, 49, 50, 51, 52,127,127,127
.byte  56, 57, 58, 59, 60, 61, 62,127
.byte  62, 63,127,127,127,127, 72, 73
.byte  80, 81, 82,127,127,127,127,127
.byte  88, 89, 90, 91, 92,127,127,127
.byte  96, 97, 98, 99,100,101,127,127
.byte 104,105,106,107,108,109,110,111
.byte 120,121,122,127,127,127,127,127
fixShift6:
.quad 4, 0, 0, 4, 0, 4, 0, 0
fixShift7:
.quad 24,12, 4,40,28,16, 4,44
# The constant 1
one:
.quad 1

# The result is 2048 bit. ceil(2048/52) = 40. ceil(40/8) = 5.
# Therefore 5 registers for the result.
.set ACC0, %zmm0
.set ACC1, %zmm1
.set ACC2, %zmm2
.set ACC3, %zmm3
.set ACC4, %zmm4
# The inputs are 1024 bit. ceil(1024/52) = 20. ceil(20/8) = 3.
.set A0, %zmm5
.set A1, %zmm6
.set A2, %zmm7
.set A3, %zmm8

.set B0, %zmm9
.set B1, %zmm10
.set B2, %zmm11
# Second set of accumulators, for throughput
.set ACC0b, %zmm12
.set ACC1b, %zmm13
.set ACC2b, %zmm14
.set ACC3b, %zmm15
# Helper registers
.set ZERO, %zmm16      # always zero
.set IDX, %zmm17       # current index for the permutation
.set ONE, %zmm18       # (uint64_t)1, broadcasted
.set MINUS_ONE, %zmm19 # max uint64_t, broadcasted

.set T0, %zmm20
.set T1, %zmm21
.set T2, %zmm22
# ABI registers
.set res, %rdi
.set a, %rsi
.set b, %rdx
# Iterators
.set itr1, %rax
.set itr2, %rcx

# void mul1024_vpmadd(uint64_t res[32], uint64_t a[16], uint64_t b[16]);
.globl mul1024_vpmadd
.type mul1024_vpmadd, @function
mul1024_vpmadd:

    mov   $0xfff, %ecx
    kmovd %ecx, %k1

    vpxorq ZERO, ZERO, ZERO
    vpxorq IDX, IDX, IDX
    # First we need to convert the input from radix 2^64 to redundant 2^52
    vmovdqa64 permMask(%rip), T0
    vmovdqa64 shiftMask(%rip), T1
    vpbroadcastq one(%rip), ONE
    # Load values with 52-byte intervals and shuffle + shift accordingly
    # First A
    vpermw 52*0(a), T0, A0
    vpermw 52*1(a), T0, A1
    vmovdqu16 52*2(a), A2{%k1}{z}
    vpermw A2, T0, A2

    vpsrlvq T1, A0, A0
    vpsrlvq T1, A1, A1
    vpsrlvq T1, A2, A2
    vpxorq A3, A3, A3
    # Then B
    vpermw 52*0(b), T0, B0
    vpermw 52*1(b), T0, B1
    vmovdqu16 52*2(b), B2{%k1}{z}
    vpermw B2, T0, B2

    vpsrlvq T1, B0, B0
    vpsrlvq T1, B1, B1
    vpsrlvq T1, B2, B2
    # Zero the accumulators, since IFMA must always add
    vpxorq ACC0, ACC0, ACC0
    vpxorq ACC1, ACC1, ACC1
    vpxorq ACC2, ACC2, ACC2
    vpxorq ACC3, ACC3, ACC3
    vpxorq ACC4, ACC4, ACC4

    vpxorq ACC1b, ACC1b, ACC1b
    vpxorq ACC2b, ACC2b, ACC2b
    vpxorq ACC3b, ACC3b, ACC3b
    # The classic approach is to multiply by a single digit of B
    # each iteration, however we prefer to multiply by all digits
    # with 8-digit interval, while the registers are aligned, and then
    # shift. We have a total of 20 digits, therefore we multipy A in 8
    # iterations by the following digits:
    # itr 0: 0,8,16
    # itr 1: 1,9,17
    # itr 2: 2,10,18
    # itr 3: 3,11,19
    # itr 4: 4,12
    # itr 5: 5,13
    # itr 6: 6,14
    # itr 7: 7,15
    # IDX holds the index of the currently required value
    mov $5, itr1
    mov $4, itr2
1:
        # Get the correct digits into T0, T1 and T2
        vpermq B0, IDX, T0
        vpermq B1, IDX, T1
        vpermq B2, IDX, T2
        vpaddq ONE, IDX, IDX
        # Multiply the correctly aligned values
        vpmadd52luq A0, T0, ACC0
        vpmadd52luq A1, T0, ACC1
        vpmadd52luq A2, T0, ACC2

        vpmadd52luq A0, T1, ACC1b
        vpmadd52luq A1, T1, ACC2b
        vpmadd52luq A2, T1, ACC3b

        vpmadd52luq A0, T2, ACC2
        vpmadd52luq A1, T2, ACC3
        vpmadd52luq A2, T2, ACC4

        dec itr1
        jz  3f

        # We need to align the accumulator, but that will a) create dependency
        # on the output of the previous IFMA operation b) there are two sets
        # of accumulators.
        # Instead we align A. However A will overflow after 4 such iterations,
        # this is when we switch to a slightly different loop

        valignq  $7, A1, A2, A2
        valignq  $7, A0, A1, A1
        valignq  $7, ZERO, A0, A0

        # Now we perform the high half of the multiplications
        vpmadd52huq A0, T0, ACC0
        vpmadd52huq A1, T0, ACC1b
        vpmadd52huq A2, T0, ACC2b

        vpmadd52huq A0, T1, ACC1
        vpmadd52huq A1, T1, ACC2
        vpmadd52huq A2, T1, ACC3

        vpmadd52huq A0, T2, ACC2b
        vpmadd52huq A1, T2, ACC3b
        vpmadd52huq A2, T2, ACC4

    jmp 1b

2:
        # Get the correct digits into T0 and T1
        # We finished all the digits in B2
        vpermq B0, IDX, T0
        vpermq B1, IDX, T1
        vpaddq ONE, IDX, IDX
        # Multiply the correctly aligned values, since A overflowed we now
        # have more multiplications
        vpmadd52luq A0, T0, ACC0
        vpmadd52luq A1, T0, ACC1
        vpmadd52luq A2, T0, ACC2
        vpmadd52luq A3, T0, ACC3

        vpmadd52luq A0, T1, ACC1b
        vpmadd52luq A1, T1, ACC2b
        vpmadd52luq A2, T1, ACC3b
        vpmadd52luq A3, T1, ACC4

        # This is the entry point for the second loop
        3:
        valignq  $7, A2, A3, A3
        valignq  $7, A1, A2, A2
        valignq  $7, A0, A1, A1
        valignq  $7, ZERO, A0, A0

        # Now we perform the high half of the multiplications
        vpmadd52huq A0, T0, ACC0
        vpmadd52huq A1, T0, ACC1b
        vpmadd52huq A2, T0, ACC2b
        vpmadd52huq A3, T0, ACC3b

        vpmadd52huq A0, T1, ACC1
        vpmadd52huq A1, T1, ACC2
        vpmadd52huq A2, T1, ACC3
        vpmadd52huq A3, T1, ACC4

        dec itr2
    jnz 2b

    # We now sum up the two pairs of accumulators
    vpaddq ACC1b, ACC1, ACC1
    vpaddq ACC2b, ACC2, ACC2
    vpaddq ACC3b, ACC3, ACC3
    # And convert to radix 2^64
    # This step can be avoided if the result will be used for other
    # operations in radix 2^52
    vmovdqa64 fixMask0(%rip), T0
    vmovdqa64 fixMask1(%rip), T1
    vpermi2b ACC1, ACC0, T0
    vpermi2b ACC1, ACC0, T1
    vpsrlvq fixShift0(%rip), T0, ACC0
    vpsllvq fixShift1(%rip), T1, ACC0b

    vmovdqa64 fixMask2(%rip), T0
    vmovdqa64 fixMask3(%rip), T1
    vpermi2b ACC2, ACC1, T0
    vpermi2b ACC2, ACC1, T1
    vpsrlvq fixShift2(%rip), T0, ACC1
    vpsllvq fixShift3(%rip), T1, ACC1b
    # a tiny fix
    mov $0x802, %eax
    kmovd %eax, %k5
    vpslld $8, ACC1, ACC1{%k5}

    vmovdqa64 fixMask4(%rip), T0
    vmovdqa64 fixMask5(%rip), T1
    vpermi2b ACC3, ACC2, T0
    vpermi2b ACC3, ACC2, T1
    vpsrlvq fixShift4(%rip), T0, ACC2
    vpsllvq fixShift5(%rip), T1, ACC2b
    # a tiny fix
    mov $0x800000, %eax
    kmovd %eax, %k5
    vpsllw $8, ACC2, ACC2{%k5}

    vmovdqa64 fixMask6(%rip), T0
    vmovdqa64 fixMask7(%rip), T1
    vpermi2b ACC4, ACC3, T0
    vpermi2b ACC4, ACC3, T1
    vpsrlvq fixShift6(%rip), T0, ACC3
    vpsllvq fixShift7(%rip), T1, ACC3b
    # a tiny fix
    mov $0x10, %eax
    kmovd %eax, %k5
    vpsrld $8, ACC3b, ACC3b{%k5}
    # Add and propagate carry
    vpaddq ACC0b, ACC0, ACC0
    vpaddq ACC1b, ACC1, ACC1
    vpaddq ACC2b, ACC2, ACC2
    vpaddq ACC3b, ACC3, ACC3

    vpsubq ONE, ZERO, MINUS_ONE

    vpcmpuq $1, ACC0b, ACC0, %k1
    vpcmpuq $1, ACC1b, ACC1, %k2
    vpcmpuq $1, ACC2b, ACC2, %k3
    vpcmpuq $1, ACC3b, ACC3, %k4

    kmovb %k1, %eax
    kmovb %k2, %ecx
    kmovb %k3, %edx
    kmovb %k4, %esi

    add %al,  %al
    adc %cl,  %cl
    adc %dl,  %dl
    adc %sil, %sil

    vpcmpuq $0, MINUS_ONE, ACC0, %k1
    vpcmpuq $0, MINUS_ONE, ACC1, %k2
    vpcmpuq $0, MINUS_ONE, ACC2, %k3
    vpcmpuq $0, MINUS_ONE, ACC3, %k4

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

    vpsubq MINUS_ONE, ACC0, ACC0{%k1}
    vpsubq MINUS_ONE, ACC1, ACC1{%k2}
    vpsubq MINUS_ONE, ACC2, ACC2{%k3}
    vpsubq MINUS_ONE, ACC3, ACC3{%k4}

    vmovdqu64 ACC0, 64*0(res)
    vmovdqu64 ACC1, 64*1(res)
    vmovdqu64 ACC2, 64*2(res)
    vmovdqu64 ACC3, 64*3(res)

    ret
.size mul1024_vpmadd, .-mul1024_vpmadd
