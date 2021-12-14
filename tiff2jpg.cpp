#include "blockcutter.h"
#include <iostream>
#include <string>
#include <cstdlib>

void print_help()
{
    printf("tiff2jpg\n");
    printf("\tusage: tiff2jpg [-quality QQ] [-color true|false] source dest\n");
    printf("\tQQ is between 1 and 100\n");
    printf("\tcolor is false by default, this means that the jpeg is greyscale\n");
}

int main(int argc, char **argv)
{
    int quality = 75;
    bool color = false;
    std::string source, dest;
    int i = 1;
    while (i < argc) {
		if (argv[i][0] == '-') {
            if (strcmp(argv[i], "-help") == 0) {
                print_help();
                return 0;
            } else if (strcmp(argv[i], "-quality") == 0) {
                if (i + 1 < argc) {
                    ++i;
                    char *ptr;
                    quality = strtoul(argv[i], &ptr, 10);
                    if (ptr == argv[i] || quality < 1 || quality > 100) {
                        fprintf(stderr, "ERROR: quality should be between 1 and 100\n");
                        return 1;
                    }
                } else {
                    fprintf(stderr, "ERROR: Missing parameter for quality\n");
                    return 1;
                }
            } else if (strcmp(argv[i], "-color") == 0) {
                if (i + 1 < argc) {
                    ++i;
                    if (strcmp(argv[i], "true") == 0) {
                        color = true;
                    } else if (strcmp(argv[i], "false") == 0) {
                        color =false;
                    } else {
                        fprintf(stderr, "ERROR: unkown parameter for color\n");
                        return 1;
                    }
                } else {
                    fprintf(stderr, "ERROR: Missing parameter for color\n");
                    return 1;
                }
            } else {
                fprintf(stderr, "ERROR: unknown parameter %s\n", argv[i]);
                return 1;
            }
        } else {
            if (source.empty()) {
                source = argv[i];
            } else if (dest.empty()) {
                dest = argv[i];
            } else {
                printf("source: %s\n", source.c_str());
                printf("dest:   %s\n", dest.c_str());
                fprintf(stderr, "ERROR: extra parameter %s\n", argv[i]);
                return 1;
            }
        }
        ++i;
    }
    block_cutter bc;
    if (source.empty() || dest.empty()) {
        fprintf(stderr, "ERROR: no filename given\n");
        print_help();
        return 0;
    } else {
        bc.convert_file(source, dest, 1.0f, quality, color);
    }
    return 0;
}
