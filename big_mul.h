/*
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

#ifndef BIG_MUL_H
#define BIG_MUL_H

#include <stdint.h>

void mul1024_avx512(uint64_t  res[32], uint64_t a[16], uint64_t b[16]);
void mul2048_avx512(uint64_t  res[64], uint64_t a[32], uint64_t b[32]);
void mul3072_avx512(uint64_t  res[96], uint64_t a[48], uint64_t b[48]);
void mul4096_avx512(uint64_t res[128], uint64_t a[64], uint64_t b[64]);

void mul1024_vpmadd(uint64_t  res[32], uint64_t a[16], uint64_t b[16]);
void mul2048_vpmadd(uint64_t  res[64], uint64_t a[32], uint64_t b[32]);
void mul3072_vpmadd(uint64_t  res[96], uint64_t a[48], uint64_t b[48]);
void mul4096_vpmadd(uint64_t res[128], uint64_t a[64], uint64_t b[64]);

#endif
