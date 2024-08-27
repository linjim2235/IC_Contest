// common.h
#ifndef COMMON_H
#define COMMON_H

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <stdarg.h>
#include <assert.h>
#include <iostream>
#include <fstream>
#include <string>
#include <chrono>
#include <iomanip>
#include <vector>
#include <cstring>
#include <thread>
#include <mutex>
#include <condition_variable>

using namespace std;


const streamsize blocksize = (1 << 19); // 1 block = 512KB
const int RUN_LEN_ENCODE1 = 224;
const int RUN_LEN_ENCODE2 = (255 - RUN_LEN_ENCODE1) << 8;
const int RUN_THRESHOLD = 3;
const int MAX_RUN = 0xFFFF + RUN_LEN_ENCODE2 + RUN_THRESHOLD - 1;
const int MAX_RUN4 = MAX_RUN - 4;
const int MIN_BLOCK_LENGTH = 16;
const char DEFAULT_ESCAPE = char(0xFB);

ofstream outputFile;

 static void panic(const char *fmt, ...) {
     va_list arg;
     va_start(arg, fmt);
     fputs("Error: ", stderr);
     vfprintf(stderr, fmt, arg);
     va_end(arg);
     fputs("\n", stderr);
     exit(1);
 }

 static uint8_t* read_file(char const* filename, size_t* out_size) {
     FILE* f = fopen(filename, "rb");
     if (!f) panic("file not found: %s\n", filename);

     fseek(f, 0, SEEK_END);
     size_t size = ftell(f);
     fseek(f, 0, SEEK_SET);

     uint8_t* buf = new uint8_t[size];
     if (fread(buf, size, 1, f) != 1) panic("read failed\n");

     fclose(f);
     if (out_size) *out_size = size;

    return buf;
 }

// void write_file(const char* filename, uint8_t* data, size_t size) {
//     FILE* f = fopen(filename, "wb");
//     if (!f) panic("file could not be created: %s", filename);

//     if (fwrite(data, size, 1, f) != 1) panic("write failed");

//     fclose(f);
// }

struct SymbolStats {
    uint32_t freqs[256];
    uint32_t cum_freqs[257];

    void count_freqs(uint8_t const* in, size_t nbytes);
    void calc_cum_freqs();
    void normalize_freqs(uint32_t target_total);
};

void SymbolStats::count_freqs(uint8_t const* in, size_t nbytes) {
    for (int i = 0; i < 256; i++) freqs[i] = 0;
    for (size_t i = 0; i < nbytes; i++) freqs[in[i]]++;
}

void SymbolStats::calc_cum_freqs() {
    cum_freqs[0] = 0;
    for (int i = 0; i < 256; i++) cum_freqs[i + 1] = cum_freqs[i] + freqs[i];
}

void SymbolStats::normalize_freqs(uint32_t target_total) {
    assert(target_total >= 256);

    calc_cum_freqs();
    uint32_t cur_total = cum_freqs[256];

    for (int i = 1; i <= 256; i++)
        cum_freqs[i] = ((uint64_t)target_total * cum_freqs[i]) / cur_total;

    for (int i = 0; i < 256; i++) {
        if (freqs[i] && cum_freqs[i + 1] == cum_freqs[i]) {
            uint32_t best_freq = ~0u;
            int best_steal = -1;
            for (int j = 0; j < 256; j++) {
                uint32_t freq = cum_freqs[j + 1] - cum_freqs[j];
                if (freq > 1 && freq < best_freq) {
                    best_freq = freq;
                    best_steal = j;
                }
            }
            assert(best_steal != -1);

            if (best_steal < i) {
                for (int j = best_steal + 1; j <= i; j++) cum_freqs[j]--;
            } else {
                assert(best_steal > i);
                for (int j = i + 1; j <= best_steal; j++) cum_freqs[j]++;
            }
        }
    }

    assert(cum_freqs[0] == 0 && cum_freqs[256] == target_total);
    for (int i = 0; i < 256; i++) {
        if (freqs[i] == 0)
            assert(cum_freqs[i + 1] == cum_freqs[i]);
        else
            assert(cum_freqs[i + 1] > cum_freqs[i]);

        freqs[i] = cum_freqs[i + 1] - cum_freqs[i];
    }
}

#endif // COMMON_H
