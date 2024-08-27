// decompress.h
#ifndef DECOMPRESS_H
#define DECOMPRESS_H

#include "common.h"
#include "rans_byte.h"

//decompress

// union get_len {
//     char c[4];
//     int len;
// };

union get_len {
    char c[4];
    uint32_t len; // 修正為無符號32位整數
};

int DecompressBlock(const std::vector<char>& src, std::vector<char>& dst) {
     // Initialize dst with the correct size
    dst.clear();
    dst.reserve(blocksize);  // Ensure enough capacity for decompression
    
    int srcIdx = 0;
    int dstIdx = 0;
    const int srcEnd = src.size();
    const int dstEnd = blocksize;
    dst.resize(dstEnd, 0);
    bool res = true;
    const char escape = src[srcIdx++];
    if (src[srcIdx] == escape) {
        srcIdx++;
        if ((srcIdx < srcEnd) && (src[srcIdx] != char(0)))
            return 0;
        dst[dstIdx++] = escape;
        srcIdx++;
    }
    while (srcIdx < srcEnd) {
        if (src[srcIdx] != escape) {
            if (dstIdx >= dstEnd) {
                res = false;
                break;
            }
            dst[dstIdx++] = src[srcIdx++];
            continue;
        }
        srcIdx++;
        if (srcIdx >= srcEnd) {
            res = false;
            break;
        }
        int run = int(src[srcIdx++]);
        run &= 0xff;
        if (run == 0) {
            if (dstIdx >= dstEnd) {
                res = false;
                break;
            }
            dst[dstIdx++] = escape;
            continue;
        }
        if (run == 255) {
            if (srcIdx + 1 >= srcEnd) {
                res = false;
                break;
            }
            run = (int(src[srcIdx]) << 8) | ((src[srcIdx + 1]) & 0xff);
            run &= 0xffff;
            srcIdx += 2;
            run += RUN_LEN_ENCODE2;
        } else if (run >= RUN_LEN_ENCODE1) {
            if (srcIdx >= srcEnd) {
                res = false;
                break;
            }
            run = ((run - RUN_LEN_ENCODE1) << 8) | ((src[srcIdx]) & 0xff);
            srcIdx++;
            run += RUN_LEN_ENCODE1;
        }
        run += (RUN_THRESHOLD - 1);
        if ((dstIdx + run >= dstEnd) || (run > MAX_RUN)) {
            res = false;
            break;
        }
        memset(&dst[dstIdx], int(dst[dstIdx - 1]), int(run));
        dstIdx += run;
    }
    dst.resize(dstIdx);
    std::vector<char> dst2(dstIdx*2);
    for (int i = 0; i < dstIdx; ++i) {
        dst2[2*i+1] = ((dst[i] & 0xF0) >> 4);
        dst2[2*i] = ((dst[i] & 0x0F) << 4) + 8;
    }
    outputFile.write(dst2.data(), dstIdx*2);
    return dstIdx*2;
    // Ensure that dst doesn't get resized to a size greater than necessary
    dst.resize(dstIdx);
}

void rans_decompress_block(const std::vector<char>& compressedBlock, std::vector<char>& decompressedData) {
    size_t encoded_size = compressedBlock.size();
    const uint8_t* encoded_bytes = (const uint8_t*)compressedBlock.data();
    
    uint32_t in_size;
    memcpy(&in_size, encoded_bytes, sizeof(uint32_t));

    // Check for valid in_size value
    // if (in_size == 0 || in_size > MAX_ALLOWED_SIZE) {
    //     throw std::runtime_error("Invalid decompressed size.");
    // }

    SymbolStats stats;
    memcpy(stats.freqs, encoded_bytes + sizeof(uint32_t), sizeof(stats.freqs));
    stats.calc_cum_freqs();

    const uint8_t* encoded_data = encoded_bytes + sizeof(uint32_t) + sizeof(stats.freqs);
    size_t encoded_data_size = encoded_size - sizeof(uint32_t) - sizeof(stats.freqs);

    static const uint32_t prob_bits = 15;
    static const uint32_t prob_scale = 1 << prob_bits;

    uint8_t cum2sym[prob_scale];
    for (int s = 0; s < 256; s++) {
        for (uint32_t i = stats.cum_freqs[s]; i < stats.cum_freqs[s + 1]; i++) {
            cum2sym[i] = s;
        }
    }

    std::vector<uint8_t> dec_bytes(in_size);
    uint8_t* ptr = (uint8_t*)encoded_data;

    RansState rans0, rans1, rans2, rans3;
    RansDecInit(&rans0, &ptr);
    RansDecInit(&rans1, &ptr);
    RansDecInit(&rans2, &ptr);
    RansDecInit(&rans3, &ptr);

    RansDecSymbol dsyms[256];
    for (int i = 0; i < 256; i++) {
        RansDecSymbolInit(&dsyms[i], stats.cum_freqs[i], stats.freqs[i]);
    }

    int out_end = (in_size & ~3);
    for (int i = 0; i < out_end; i += 4) {
        uint32_t s0 = cum2sym[RansDecGet(&rans0, prob_bits)];
        uint32_t s1 = cum2sym[RansDecGet(&rans1, prob_bits)];
        uint32_t s2 = cum2sym[RansDecGet(&rans2, prob_bits)];
        uint32_t s3 = cum2sym[RansDecGet(&rans3, prob_bits)];
        dec_bytes[i + 0] = (uint8_t)s0;
        dec_bytes[i + 1] = (uint8_t)s1;
        dec_bytes[i + 2] = (uint8_t)s2;
        dec_bytes[i + 3] = (uint8_t)s3;
        RansDecAdvanceSymbolStep(&rans0, &dsyms[s0], prob_bits);
        RansDecAdvanceSymbolStep(&rans1, &dsyms[s1], prob_bits);
        RansDecAdvanceSymbolStep(&rans2, &dsyms[s2], prob_bits);
        RansDecAdvanceSymbolStep(&rans3, &dsyms[s3], prob_bits);
        RansDecRenorm(&rans0, &ptr);
        RansDecRenorm(&rans1, &ptr);
        RansDecRenorm(&rans2, &ptr);
        RansDecRenorm(&rans3, &ptr);
    }

    switch (in_size & 3) {
    case 3: {
        uint32_t s2 = cum2sym[RansDecGet(&rans2, prob_bits)];
        dec_bytes[in_size + 2] = (uint8_t)s2;
        RansDecAdvanceSymbolStep(&rans2, &dsyms[s2], prob_bits);
        RansDecRenorm(&rans2, &ptr);
    }
    case 2: {
        uint32_t s1 = cum2sym[RansDecGet(&rans1, prob_bits)];
        dec_bytes[in_size + 1] = (uint8_t)s1;
        RansDecAdvanceSymbolStep(&rans1, &dsyms[s1], prob_bits);
        RansDecRenorm(&rans1, &ptr);
    }
    case 1: {
        uint32_t s0 = cum2sym[RansDecGet(&rans0, prob_bits)];
        dec_bytes[in_size + 0] = (uint8_t)s0;
        RansDecAdvanceSymbolStep(&rans0, &dsyms[s0], prob_bits);
        RansDecRenorm(&rans0, &ptr);
    }
    default:
        break;
    }

    decompressedData.assign(dec_bytes.begin(), dec_bytes.end());
}

int decompress(const std::string& inputFileName, const std::string& outputFileName) {
    std::vector<char> compressedData;

    std::ifstream inputFile(inputFileName, std::ios::binary | std::ios::ate);
    if (!inputFile) {
        throw std::runtime_error("Cannot open input file.");
    }

    std::streamsize size = inputFile.tellg();
    inputFile.seekg(0, std::ios::beg);

    compressedData.resize(size);
    if (!inputFile.read(compressedData.data(), size)) {
        throw std::runtime_error("Error reading input file.");
    }
    inputFile.close();

    std::vector<char> finalDecompressedData;

    get_len GL1;
    get_len GL2;

    size_t offset = 0;
    while (offset < compressedData.size()) {
        if (offset + 4 > compressedData.size()) {
            throw std::runtime_error("Insufficient data to read RLT block length");
        }

        std::memcpy(GL1.c, &compressedData[offset], 4);
        offset += 4;
        GL1.len = *reinterpret_cast<uint32_t*>(GL1.c);

        if (offset + 4 > compressedData.size()) {
            throw std::runtime_error("Insufficient data to read ANS block length");
        }

        std::memcpy(GL2.c, &compressedData[offset], 4);
        offset += 4;
        GL2.len = *reinterpret_cast<uint32_t*>(GL2.c);

        if (offset + GL2.len > compressedData.size()) {
            throw std::runtime_error("Insufficient data to read ANS block");
        }

        std::vector<char> ansCompressedBlock(compressedData.begin() + offset, compressedData.begin() + offset + GL2.len);
        offset += GL2.len;

        std::vector<char> rltCompressedBlock;
        rans_decompress_block(ansCompressedBlock, rltCompressedBlock);

        if (rltCompressedBlock.size() != GL1.len) {
            throw std::runtime_error("RLT decompressed size does not match the expected block length.");
        }

        std::vector<char> decompressedBlock;
        DecompressBlock(rltCompressedBlock, decompressedBlock);

        finalDecompressedData.insert(finalDecompressedData.end(), decompressedBlock.begin(), decompressedBlock.end());
    }

    std::ofstream outputFile(outputFileName, std::ios::binary);
    if (!outputFile) {
        throw std::runtime_error("Cannot open output file.");
    }
    outputFile.write(finalDecompressedData.data(), finalDecompressedData.size());
    outputFile.close();

    return finalDecompressedData.size();
} 

#endif // DEsCOMPRESS_H
