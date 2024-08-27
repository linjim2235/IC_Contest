#include "rans_byte.h"
#include "common.h"
#include "compress.h"

int main(int argc, char *argv[]) {
    string inputFileName;
    string outputFileName;
    size_t numThreads = std::thread::hardware_concurrency();
    auto start_time = chrono::high_resolution_clock::now();
    int firstIndex= 0;
    int secondIndex= 0;
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "-i" && i + 1 < argc) {
            inputFileName = argv[++i];
        } else if (arg == "-o" && i + 1 < argc) {
            outputFileName = argv[++i];
        } else if (arg == "-n" && i + 1 < argc) {
            numThreads = stoi(argv[++i]);
        } else if (arg == "-f" && i + 1 < argc) { // firstIndex
            firstIndex = stoi(argv[++i]);
        } else if (arg == "-s" && i + 1 < argc) { // secondIndex
            secondIndex = stoi(argv[++i]);
        }
    }
    if (inputFileName.empty() || outputFileName.empty()) {
        cerr << "Error: Missing required arguments." << endl;
        cerr << "Usage: program -i ori_file -o compress_file [-n num_threads]" << endl;
        return 1;
    }
    cout<<"thread num :"<<numThreads<<endl;
    globalCompressedData.clear();

   
    //////////Reading and writing to memory; this step can be omitted since it's already in memory.///////////////////////
    ifstream inputFile(inputFileName, ios::binary);
    inputFile.is_open();

    inputFile.seekg(0, ios::end);
    size_t fileSize = inputFile.tellg();
    inputFile.seekg(0, ios::beg);

    vector<char> inputbuffer(fileSize);            //memory location
    inputFile.read(inputbuffer.data(), fileSize);
    inputFile.close();
    outputFile.open(outputFileName, ios::binary);
    /////////////////////////////////////////////////////////////////
    auto read_time = chrono::high_resolution_clock::now();
    /////////////////////////////////////////////////////////////////
    size_t halfSize = fileSize / 2;
    size_t bufferSize;
    if(secondIndex == 0){
        bufferSize = halfSize;
        secondIndex = halfSize;
    }else{
        bufferSize = (secondIndex-firstIndex);
    }
    vector<char> buffer(bufferSize);

    //process data
    ProcessMemoryData_delete(inputbuffer, bufferSize, buffer, numThreads, firstIndex, secondIndex);   // 16 bits -> 8 bits //save firstIndex to secondIndex-1
    auto ProcessMemoryData_time = chrono::high_resolution_clock::now();
    //////////////////////////////////delete front & end
    cout << "Original_BufferSize: " <<halfSize << endl;
    float deleteSize = buffer.size();
    cout << "FirstIndex: " << firstIndex << " SecondIndex: " << secondIndex << " After_BufferSize: " << buffer.size() << endl;
    cout << "BufferSize_delete_rate " << (1-(deleteSize/halfSize))*100 << "%"<< endl;
    cout << "////////////////time////////////////"<< endl;
    firstIndex=0;
    secondIndex=0;
    /////////////////////////////////
    // RLT
    size_t RLT_size = RLT_CompressData(buffer, bufferSize, blocksize,numThreads);
    //rans
    // vector<char> compressedData = rans_CompressData(globalCompressedData);
    /////////////////////////////////////////////////////////////////  
    auto exe_time = chrono::high_resolution_clock::now();

    ///////////////////////////////////////////////////////////////// 
    
    // 寫入文件
    // writeCompressedDataToFile(outputFileName, compressedData);
    // ofstream outputFile(outputFileName, ios::binary);
    if (!outputFile) {
        cerr << "無法打開輸出文件 " << outputFileName << endl;
        return 0;
    }
    vector<char> compress;
    for (const auto& vec : globalCompressedData) {
        compress.insert(compress.end(), vec.begin(), vec.end());
    }
    // 寫入壓縮數據到文件
    outputFile.write(compress.data(), compress.size());
    // 關閉文件
    outputFile.close();
    //計時結束
    auto write_time = chrono::high_resolution_clock::now();
    /////////////////////////////////////////////////////////////////  
    chrono::duration<double> read = read_time - start_time;
    chrono::duration<double> exe = exe_time - read_time;
    chrono::duration<double> write = write_time - exe_time;
    chrono::duration<double> exewrite = write_time - read_time;
    chrono::duration<double> total = write_time - start_time;
    chrono::duration<double> process = ProcessMemoryData_time - read_time;
    cout << "read file time  : " << read.count() << " second" << endl;
    cout << "compress time   : " << exe.count() << " second" << endl;
    cout << "write_file_time : " << write.count() << " second" << endl;
    cout << "exewrite time   : " << exewrite.count() << " second" << endl;
    cout << "total time      : " << total.count() << " second" << endl;
    cout << "process time    : " << process.count() << " second" << endl;
    ///////////////////////////////////////////////////////////////// 
    cout << "Original size   : " << fileSize << endl;
    size_t totalSize = 0;
    for (const auto& block : globalCompressedData) {
        totalSize += block.size(); // 累加每個區塊的大小
    }
    cout << "After ans compress size : " << totalSize << endl;
    cout << "compress rate   : " << (1 - (float(totalSize) / float(fileSize)) ) * 100 << "%" << endl;
    // cout << "After ans compress size : " << compressedData.size() << endl;
    // cout << "compress rate   : " << (1 - (float(compressedData.size()) / float(fileSize)) ) * 100 << "%" << endl;
    return 0;
}
