// compress.h
#ifndef COMPRESS_H
#define COMPRESS_H

#include "common.h"
#include "rans_byte.h"

mutex mtx;
condition_variable cv;
int nextThreadToWrite = 0;

vector<vector<char>> globalCompressedData;

int nextThreadToProcess = 0;

void processdata_delete(const std::vector<char>& inputbuffer, size_t halfSize, size_t start, size_t end, size_t firstIndex, std::vector<char>& buffer) {
    size_t bufferIndex = start - firstIndex;

    for (size_t i = start; i < end; ++i, ++bufferIndex) {
        buffer[bufferIndex] = ((inputbuffer[2 * i] & 0xF0) >> 4) + ((inputbuffer[2 * i + 1] & 0x0F) << 4);
    }
}

void ProcessMemoryData_delete(const std::vector<char>& inputbuffer, size_t bufferSize, std::vector<char>& buffer, int thread_num, size_t firstIndex, size_t secondIndex) {
    size_t numThreads = thread_num; // std::thread::hardware_concurrency();
    std::vector<std::thread> threads2(numThreads);

    size_t chunkSize = bufferSize / numThreads;

    for (size_t i = 0; i < numThreads; ++i) {
        size_t start = firstIndex + i * chunkSize;
        size_t end = (i == numThreads - 1) ? secondIndex : start + chunkSize;

        threads2[i] = std::thread(processdata_delete, std::cref(inputbuffer), bufferSize, start, end, firstIndex, std::ref(buffer));
    }

    for (auto& thread : threads2) {
        thread.join();
    }
}

vector<char> rans_CompressData(const vector<char>& compressedBlock) {
    size_t totalCompressedSize = compressedBlock.size();

    uint8_t* in_bytes = new uint8_t[totalCompressedSize];
    std::memcpy(in_bytes, compressedBlock.data(), totalCompressedSize);

    static const uint32_t prob_bits = 15;
    static const uint32_t prob_scale = 1 << prob_bits;

    size_t in_size = totalCompressedSize;

    SymbolStats stats;
    stats.count_freqs(in_bytes, in_size);
    stats.normalize_freqs(prob_scale);

    uint8_t cum2sym[prob_scale];
    for (int s = 0; s < 256; s++) {
        for (uint32_t i = stats.cum_freqs[s]; i < stats.cum_freqs[s + 1]; i++) {
            cum2sym[i] = s;
        }
    }

    static size_t out_max_size = 100 << 20; // 100MB
    uint8_t* out_buf = new uint8_t[out_max_size];
    uint8_t* ptr = out_buf + out_max_size;

    RansState rans0, rans1, rans2, rans3;
    RansEncInit(&rans0);
    RansEncInit(&rans1);
    RansEncInit(&rans2);
    RansEncInit(&rans3);

    RansEncSymbol esyms[256];
    for (int i = 0; i < 256; i++) {
        RansEncSymbolInit(&esyms[i], stats.cum_freqs[i], stats.freqs[i], prob_bits);
    }

    switch (int i = (in_size & 3)) {
    case 3: RansEncPutSymbol(&rans2, &ptr, &esyms[in_bytes[in_size - (i - 2)]]); // fallthrough
    case 2: RansEncPutSymbol(&rans1, &ptr, &esyms[in_bytes[in_size - (i - 1)]]); // fallthrough
    case 1: RansEncPutSymbol(&rans0, &ptr, &esyms[in_bytes[in_size - (i - 0)]]); // fallthrough
    case 0: break;
    }

    for (size_t i = (in_size & ~3); i > 0; i -= 4) {
        int s3 = in_bytes[i - 1];
        int s2 = in_bytes[i - 2];
        int s1 = in_bytes[i - 3];
        int s0 = in_bytes[i - 4];
        RansEncPutSymbol(&rans3, &ptr, &esyms[s3]);
        RansEncPutSymbol(&rans2, &ptr, &esyms[s2]);
        RansEncPutSymbol(&rans1, &ptr, &esyms[s1]);
        RansEncPutSymbol(&rans0, &ptr, &esyms[s0]);
    }

    RansEncFlush(&rans3, &ptr);
    RansEncFlush(&rans2, &ptr);
    RansEncFlush(&rans1, &ptr);
    RansEncFlush(&rans0, &ptr);

    uint8_t* rans_begin = ptr;
    size_t out_size = out_buf + out_max_size - rans_begin;

    vector<char> compressedData;
    compressedData.insert(compressedData.end(), reinterpret_cast<const char*>(&in_size), reinterpret_cast<const char*>(&in_size) + sizeof(uint32_t));
    compressedData.insert(compressedData.end(), reinterpret_cast<const char*>(stats.freqs), reinterpret_cast<const char*>(stats.freqs) + sizeof(stats.freqs));
    compressedData.insert(compressedData.end(), rans_begin, rans_begin + out_size);

    delete[] out_buf;
    delete[] in_bytes;

    return compressedData;
}

int emitRunLength(char dst[], int run, char escape, char val) {
    dst[0] = val;
    dst[1] = char(0);
    int dstIdx = (val == escape) ? 2 : 1;
    dst[dstIdx++] = escape;
    run -= RUN_THRESHOLD;

    if (run >= RUN_LEN_ENCODE1) {
        if (run < RUN_LEN_ENCODE2) {
            run -= RUN_LEN_ENCODE1;
            dst[dstIdx++] = char(RUN_LEN_ENCODE1 + (run >> 8));
        } else {
            run -= RUN_LEN_ENCODE2;
            dst[dstIdx++] = char(0xFF);
            dst[dstIdx++] = char(run >> 8);
        }
    }

    dst[dstIdx] = char(run);
    return dstIdx + 1;
}

int CompressBlock(const vector<char>& src, streamsize bytesRead, vector<char>& dst) {

    // streamsize newsize = bytesRead / 2;
    // vector<char> src(newsize);
    // for (size_t i = 0; i < newsize; i++) {
    //     src[i] = ((source[2*i] & 0xF0) >> 4) + ((source[2*i+1] & 0x0F) << 4);
    // }




    int srcIdx = 0;
    int dstIdx = 0;
    int srcEnd = bytesRead;
    int srcEnd4 = srcEnd - 4;

    int dstEnd = bytesRead + 10;
    
    dst.resize(dstEnd);
    bool res = true;
    int run = 0;
    char escape = DEFAULT_ESCAPE;
    char prev = src[srcIdx++];
    dst[dstIdx++] = escape;
    dst[dstIdx++] = prev;

    if (prev == escape)
        dst[dstIdx++] = char(0);

    while (true) {
        if (prev == src[srcIdx]) {
            const unsigned int v = 0x01010101 * ((prev) & 0xff);
            if (memcmp(&v, &src[srcIdx], 4) == 0) {
                srcIdx += 4;
                run += 4;
                if ((run < MAX_RUN4) && (srcIdx < srcEnd4))
                    continue;
            } else if (prev == src[srcIdx]) {
                srcIdx++;
                run++;
                if (prev == src[srcIdx]) {
                    srcIdx++;
                    run++;
                    if (prev == src[srcIdx]) {
                        srcIdx++;
                        run++;
                        if ((run < MAX_RUN4) && (srcIdx < srcEnd4))
                            continue;
                    }
                }
            }
        }

        if (run > RUN_THRESHOLD) {
            if (dstIdx + 6 >= dstEnd) {
                res = false;
                break;
            }
            dstIdx += emitRunLength(&dst[dstIdx], run, escape, prev);
        } else if (prev != escape) {
            if (dstIdx + run >= dstEnd) {
                res = false;
                break;
            }

            if (run-- > 0)
                dst[dstIdx++] = prev;

            while (run-- > 0)
                dst[dstIdx++] = prev;
        } else {
            if (dstIdx + (2 * run) >= dstEnd) {
                res = false;
                break;
            }

            while (run-- > 0) {
                dst[dstIdx++] = escape;
                dst[dstIdx++] = char(0);
            }
        }

        prev = src[srcIdx];
        srcIdx++;
        run = 1;
        if (srcIdx >= srcEnd4)
            break;
    }

    if (res == true) {
        if (prev != escape) {
            if (dstIdx + run < dstEnd) {
                while (run-- > 0)
                    dst[dstIdx++] = prev;
            }
        } else {
            if (dstIdx + (2 * run) < dstEnd) {
                while (run-- > 0) {
                    dst[dstIdx++] = escape;
                    dst[dstIdx++] = char(0);
                }
            }
        }

        while ((srcIdx < srcEnd) && (dstIdx < dstEnd)) {
            if (src[srcIdx] == escape) {
                if (dstIdx + 2 >= dstEnd) {
                    res = false;
                    break;
                }

                dst[dstIdx++] = escape;
                dst[dstIdx++] = char(0);
                srcIdx++;
                continue;
            }
            dst[dstIdx++] = src[srcIdx++];
        }
        res &= (srcIdx == srcEnd);
    }

    dst.resize(dstIdx);
    return dstIdx;
    cout<<dstIdx<<endl;
}

void CompressBlocks(const vector<char>& buffer, size_t bufferSize, size_t start, size_t end, int threadIdx, int& totalSize) {
    int size = 0;
    int size2 = 0;
    vector<vector<char>> compressedBlocks;

    for (size_t offset = start; offset < end; ) {
        // 設定目前的區塊大小 (最多 blocksize)
        size_t currentBlockSize = min(blocksize, static_cast<streamsize>(bufferSize - offset));
        vector<char> currentBlock(buffer.begin() + offset, buffer.begin() + offset + currentBlockSize);
        
        // RLT 壓縮
        vector<char> rltCompressedBlock;
        size += CompressBlock(currentBlock, currentBlockSize, rltCompressedBlock);

        // ANS 壓縮
        vector<char> ansCompressedBlock = rans_CompressData(rltCompressedBlock);
        size2 += ansCompressedBlock.size();

        // 將 RLT 和 ANS 壓縮長度記錄下來
        int rltLength = rltCompressedBlock.size();
        int ansLength = ansCompressedBlock.size();

        // 儲存 RLT 長度
        const char* rltLengthPtr = reinterpret_cast<const char*>(&rltLength);
        compressedBlocks.push_back(vector<char>(rltLengthPtr, rltLengthPtr + sizeof(rltLength)));

        // 儲存 ANS 長度
        const char* ansLengthPtr = reinterpret_cast<const char*>(&ansLength);
        compressedBlocks.push_back(vector<char>(ansLengthPtr, ansLengthPtr + sizeof(ansLength)));

        // 儲存 ANS 壓縮的數據
        compressedBlocks.push_back(move(ansCompressedBlock));

        // 更新偏移量以處理下一個區塊
        offset += currentBlockSize;
    }
    
    {
        unique_lock<mutex> lock(mtx);
        cv.wait(lock, [&]() { return threadIdx == nextThreadToWrite; });

        // 將所有區塊和長度訊息寫入 globalCompressedData
        for (const auto& block : compressedBlocks) {
            globalCompressedData.push_back(block);
        }

        totalSize += size2;
        nextThreadToWrite++;
        cv.notify_all();
    }
}

// void CompressBlocks(const vector<char>& buffer, size_t bufferSize, size_t start, size_t end, int threadIdx, int& totalSize) {
//     int rltSize = 0;
//     vector<vector<char>> rltCompressedBlocks;
    
//     // 第一階段：對每個區塊進行 RLT 壓縮
//     for (size_t offset = start; offset < end; ) {
//         // 設定目前的區塊大小 (最多 blocksize)
//         size_t currentBlockSize = min(blocksize, static_cast<streamsize>(bufferSize - offset));
//         vector<char> currentBlock(buffer.begin() + offset, buffer.begin() + offset + currentBlockSize);
        
//         // RLT 壓縮
//         vector<char> rltCompressedBlock;
//         rltSize += CompressBlock(currentBlock, currentBlockSize, rltCompressedBlock);
//         rltCompressedBlocks.push_back(move(rltCompressedBlock));
        
//         // 更新偏移量以處理下一個區塊
//         offset += currentBlockSize;
//     }

//     // 第二階段：對所有 RLT 壓縮過的區塊進行 ANS 壓縮
//     int ansSize = 0;
//     vector<vector<char>> compressedBlocks;

//     for (auto& rltCompressedBlock : rltCompressedBlocks) {
//         // ANS 壓縮
//         vector<char> ansCompressedBlock = rans_CompressData(rltCompressedBlock);
//         ansSize += ansCompressedBlock.size();

//         // 儲存 RLT 和 ANS 壓縮長度
//         int rltLength = rltCompressedBlock.size();
//         int ansLength = ansCompressedBlock.size();

//         // 儲存 RLT 壓縮長度
//         const char* rltLengthPtr = reinterpret_cast<const char*>(&rltLength);
//         compressedBlocks.push_back(vector<char>(rltLengthPtr, rltLengthPtr + sizeof(rltLength)));

//         // 儲存 ANS 壓縮長度
//         const char* ansLengthPtr = reinterpret_cast<const char*>(&ansLength);
//         compressedBlocks.push_back(vector<char>(ansLengthPtr, ansLengthPtr + sizeof(ansLength)));

//         // 儲存 ANS 壓縮的數據
//         compressedBlocks.push_back(move(ansCompressedBlock));
//     }
    
//     {
//         unique_lock<mutex> lock(mtx);
//         cv.wait(lock, [&]() { return threadIdx == nextThreadToWrite; });

//         // 將所有區塊和長度訊息寫入 globalCompressedData
//         for (const auto& block : compressedBlocks) {
//             globalCompressedData.push_back(block);
//         }

//         totalSize += ansSize;  // 更新總大小，這裡使用 ANS 壓縮後的大小
//         nextThreadToWrite++;
//         cv.notify_all();
//     }
// }

size_t RLT_CompressData(std::vector<char>& buffer, size_t halfSize, size_t blockSize,int thread_num) {
    size_t numThreads =thread_num;// std::thread::hardware_concurrency();
    std::vector<std::thread> threads;
    std::vector<int> threadSizes(numThreads, 0);
    size_t chunkSize = halfSize / numThreads;
    chunkSize = chunkSize - (chunkSize % blockSize);

    for (size_t i = 0; i < numThreads; ++i) {
        size_t start = i * chunkSize;
        size_t end = (i == numThreads - 1) ? halfSize : start + chunkSize;
        if (start >= halfSize) {
            cerr << "Error: start >= halfSize, start = " << start << ", halfSize = " << halfSize << endl;
            break;
        }
        if (end > halfSize) {
            end = halfSize;
        }
        threads.emplace_back(CompressBlocks, std::ref(buffer), halfSize, start, end, i, std::ref(threadSizes[i]));
    }

    for (auto& thread : threads) {
        thread.join();
    }

    size_t totalSize = 0;
    for (auto size : threadSizes) {
        totalSize += size;
    }

    return totalSize;
}

void writeCompressedDataToFile(const string& fileName, const vector<char>& compressedData) {
    ofstream outputFile(fileName, ios::binary);
    if (!outputFile) {
        cerr << "無法打開輸出文件 " << fileName << endl;
        return ;
    }

    // 寫入壓縮數據到文件
    outputFile.write(compressedData.data(), compressedData.size());

    // 關閉文件
    outputFile.close();

    return ;
}

#endif // COMPRESS_H
