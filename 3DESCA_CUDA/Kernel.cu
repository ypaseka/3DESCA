#include "TDES.cuh"
#include "Chunk.cuh"
#include <Timer.hpp>

#include <cuda.h>

namespace CUDA {

__global__ void kernelEncode(TDESCA::chunk64* keys, TDESCA::chunk64* dataIn,
                             TDESCA::chunk64* dataOut)
{
    int ind = threadIdx.x + blockIdx.x * 256;
    TDESCA::TDES cipher;
    dataOut[ind] = cipher.Encode(keys[0], keys[1], keys[2], dataIn[ind]);
}

__global__ void kernelDecode(TDESCA::chunk64* keys, TDESCA::chunk64* dataIn,
                             TDESCA::chunk64* dataOut)
{
    int ind = threadIdx.x + blockIdx.x * 256;
    TDESCA::TDES cipher;
    dataOut[ind] = cipher.Decode(keys[0], keys[1], keys[2], dataIn[ind]);
}

void CudaEncode(TDESCA::chunk64 key1, TDESCA::chunk64 key2,
                TDESCA::chunk64 key3, TDESCA::chunk64* dataIn,
                unsigned int chunkCount, TDESCA::chunk64* dataOut, double* timeOut)
{
    Timer timer;

    TDESCA::chunk64* cudaDataIn;
    TDESCA::chunk64* cudaDataOut;
    TDESCA::chunk64* cudaKeys;
    cudaError_t err;

    err = cudaMalloc(&cudaDataIn, chunkCount * sizeof(TDESCA::chunk64));
    err = cudaMalloc(&cudaKeys, 3 * sizeof(TDESCA::chunk64));
    err = cudaMalloc(&cudaDataOut, chunkCount * sizeof(TDESCA::chunk64));

    TDESCA::chunk64 keys[] = { key1, key2, key3 };

    err = cudaMemcpy(cudaDataIn, dataIn, chunkCount * sizeof(TDESCA::chunk64), cudaMemcpyHostToDevice);
    err = cudaMemcpy(cudaKeys, keys, 3 * sizeof(TDESCA::chunk64), cudaMemcpyHostToDevice);

    cudaDeviceSynchronize();

    const unsigned int threadCount = 256;
    const unsigned int blockCount = chunkCount / 256;

    timer.start();
    kernelEncode<<<blockCount, threadCount>>>(cudaKeys, cudaDataIn, cudaDataOut);
    cudaDeviceSynchronize();
    *timeOut = timer.stopNs();

    err = cudaMemcpy(dataOut, cudaDataOut, chunkCount * sizeof(TDESCA::chunk64), cudaMemcpyDeviceToHost);
    cudaFree(cudaDataIn);
    cudaFree(cudaKeys);
    cudaFree(cudaDataOut);
}

void CudaDecode(TDESCA::chunk64 key1, TDESCA::chunk64 key2,
                TDESCA::chunk64 key3, TDESCA::chunk64* dataIn,
                unsigned int chunkCount, TDESCA::chunk64* dataOut, double* timeOut)
{
    Timer timer;

    TDESCA::chunk64* cudaDataIn;
    TDESCA::chunk64* cudaDataOut;
    TDESCA::chunk64* cudaKeys;
    cudaMalloc(&cudaDataIn, chunkCount * sizeof(TDESCA::chunk64));
    cudaMemcpy(cudaDataIn, dataIn, chunkCount * sizeof(TDESCA::chunk64), cudaMemcpyHostToDevice);

    cudaMalloc(&cudaKeys, 3 * sizeof(TDESCA::chunk64));
    TDESCA::chunk64 keys[] = { key1, key2, key3 };
    cudaMemcpy(cudaKeys, keys, 3 * sizeof(TDESCA::chunk64), cudaMemcpyHostToDevice);

    cudaMalloc(&cudaDataOut, chunkCount * sizeof(TDESCA::chunk64));

    const unsigned int threadCount = 256;
    const unsigned int blockCount = chunkCount / 256;

    timer.start();
    kernelDecode<<<blockCount, threadCount>>>(cudaKeys, cudaDataIn, cudaDataOut);
    cudaDeviceSynchronize();
    *timeOut = timer.stopNs();

    cudaMemcpy(dataOut, cudaDataOut, chunkCount * sizeof(TDESCA::chunk64), cudaMemcpyDeviceToHost);
    cudaFree(cudaDataIn);
    cudaFree(cudaDataOut);
    cudaFree(cudaKeys);
}

} // namespace CUDA