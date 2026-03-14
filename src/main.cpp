#include <assert.h>
#include <stdio.h>
#include <string.h>

#include <vector>

#include <hip/hip_runtime.h>

__global__ void hello_k() { printf("Hello from GPU!\n"); }

bool is_bf_code(char c) {
  switch (c) {
  case '<':
  case '>':
  case ',':
  case '.':
  case '+':
  case '-':
  case '[':
  case ']':
    return true;
  default:
    return false;
  }
}

static const char *hello() {
  return "++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++"
         ".>>.<-.<.+++.------.--------.>>+.>++.";
}

static void run(const char *code, size_t code_len, char *tape, size_t tape_len,
                size_t ip, size_t sp, std::vector<size_t> stack) {
  if (ip >= code_len || sp >= tape_len)
    return;

  switch (code[ip]) {
  case '+':
    tape[sp] += 1;
    break;
  case '-':
    tape[sp] -= 1;
    break;
  case '<':
    if (sp == 0)
      return;
    sp -= 1;
    break;
  case '>':
    sp += 1;
    break;
  case ',':
    tape[sp] = (char)getchar();
    break;
  case '.':
    putchar(tape[sp]);
    break;
  case '[':
    if (tape[sp] == 0) {
      auto ip0 = ip;
      do {
        ip += 1;
      } while (ip < code_len && code[ip] != ']');
      if (ip == code_len) {
        fprintf(stderr, "runaway loop at %zu\n", ip0);
        return;
      }
    } else {
      stack.push_back(ip);
    }
    break;
  case ']':
    if (stack.empty()) {
      fprintf(stderr, "empty stack at %zu\n", ip);
      return;
    }
    if (tape[sp] != 0) {
      ip = stack.back();
    } else {
      stack.pop_back();
    }
    break;
  }

  run(code, code_len, tape, tape_len, ip + 1, sp, stack);
}

int main() {
  hipLaunchKernelGGL(hello_k, dim3(1), dim3(1), 0, 0);
  auto err = hipDeviceSynchronize();
  if (err) {
    fprintf(stderr, "synchronize failed: %s\n", hipGetErrorString(err));
  }

  auto h = hello();
  size_t stack_sz = 100;
  auto buf = (char *)alloca(stack_sz);
  memset(buf, 0, stack_sz);
  run(h, strlen(h) - 1, buf, stack_sz, 0, 0, std::vector<size_t>{});
  puts("");

  return 0;
}
