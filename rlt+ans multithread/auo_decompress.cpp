#include "common.h"
#include "rans_byte.h"
#include "decompress.h"

int main(int argc, char *argv[]) {
    string inputFileName;  //選擇inputfile
    string outputFileName;          //選擇outputfile
    for (int i = 1; i < argc; ++i) {
        string arg = argv[i];
        if (arg == "-i" && i + 1 < argc) {
            inputFileName = argv[++i];
        } else if (arg == "-o" && i + 1 < argc) {
            outputFileName = argv[++i];
        }
    }
    if (inputFileName.empty() || outputFileName.empty()) {
        cerr << "Error: Missing required arguments." << endl;
        cerr << "Usage: program -i compress_file -o rec_file" << endl;
        return 1;
    }
    outputFile.open(outputFileName, std::ios::binary);

    //計時開始
    auto start = std::chrono::high_resolution_clock::now();

    vector<char> firstDecompressedData;

    //rans decompress
    // rans_decompress(inputFileName, firstDecompressedData);

    //RLT decompress
    // int size = RLT_decompress(firstDecompressedData, outputFileName);

    int size = decompress(inputFileName, outputFileName);


    //計時結束
    auto end = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double> elapsed = end - start;

    cout << "還原後總大小: " << size << endl;

    cout << "時間: " << elapsed.count() << endl;
    return 0;
}
