#include <hip/hip_runtime.h>
#include <iostream>

__global__ void hello() { printf("Hello from GPU!\n"); }

int main() {
  hipLaunchKernelGGL(hello, dim3(1), dim3(1), 0, 0);
  auto err = hipDeviceSynchronize();
  if (err) {
    fprintf(stderr, "synchronize failed: %s\n", hipGetErrorString(err));
  }
  return 0;
}
