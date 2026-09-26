/* Inspect the host ABI used by ALIS savestates; do not assume offsets across builds.
 * Source: maestun/alis 19a95afdc07b45d997467806d4dd1bf83c5f8076,
 * src/alis.c:551 alis_save_state and src/alis.h sAlisVM. */
#include <stdio.h>
#include <stddef.h>
#include "alis.h"
int main(void) {
 printf("{\"struct_size\":%zu,\"basemain_offset\":%zu,\"basemain_size\":%zu,\"size_t_bytes\":%zu}\n",sizeof(sAlisVM),offsetof(sAlisVM,basemain),sizeof(((sAlisVM*)0)->basemain),sizeof(size_t));
 return 0;
}
