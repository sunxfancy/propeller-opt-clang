#include <stdlib.h>

__attribute__((noinline))
size_t report(size_t a) {
    static size_t first = 1;
    if (first == 1) {
        first = 0;
        printf("%zu %zu %zu %zu %zu\n", a, a+1, a+2, a+3, a+4);
    }
    return 0;
}

__attribute__((noinline))
size_t func(size_t k) {
    size_t a = k+1;
    size_t b = k-2;
    size_t c = k*3;
    size_t d = k-4;
    size_t e = k+5;

    for (size_t i = 0; i < k; ++i) {
        if (i == k-1) {
            report(a);
        } else {
            a += 1;
            b += 2;
            c += b+1;
            d += 4;
            e += d-1;
        }
    }
    return a+b+c+d+e;
}




int main(int argc, char *argv[]) {
    size_t k = 0;
    k = atoi(argv[1]);
    for (size_t i = 0; i < 100; ++i) {
        printf("ans = %zu\n", func(k));    
    }
    return 0;
}