#include <stdio.h>
#include <stdlib.h>
#include "blockcutter.h"
#include <iostream>
#include <string>

void print_help()
{
	printf("mytiffcrop\n");
	printf("\tcrop multiple JPG files out of a big TIFF file. The program takes its arguments through stdin and performs the operation on the \"docrop\" command.\n");
	printf("example usage:\n");
	printf("source: blah.tiff\n");
	printf("crop WxH+X+Y out1.jpg\n");
	printf("crop WxH+X+Y out2.jpg\n");
	printf("docrop\n");
	printf("source: xxx.tiff\n");
	printf("...\n");
	printf("\toptionally, you may specify a JPEG quality (1 - 100) at any point. It will apply to the next docrop operation\n");
	printf("quality: QQ\n");
}

bool parse_crop(const std::string &line, alto_rectangle &ar, std::string &filename)
{
	const char *l = line.c_str() + 5;
	char *ptr;
	ar.width = strtoul(l, &ptr, 10);
	if (ptr == l) {
		fprintf(stderr, "crop error, expected number at %s\n", l);
		return false;
	}
	if (*ptr != 'x') {
		fprintf(stderr, "crop error, expected 'x' at %s\n", ptr);
		return false;
	}
	l = ptr + 1;
	ar.height = strtoul(l, &ptr, 10);
	if (ptr == l) {
		fprintf(stderr, "crop error, expected number at %s\n", l);
		return false;
	}
	if (*ptr != '+') {
		fprintf(stderr, "crop error, expected '+' at %s\n", ptr);
		return false;
	}
	l = ptr + 1;
	ar.x = strtoul(l, &ptr, 10);
	if (ptr == l) {
		fprintf(stderr, "crop error, expected number at %s\n", l);
		return false;
	}
	if (*ptr != '+') {
		fprintf(stderr, "crop error, expected '+' at %s\n", ptr);
		return false;
	}
	l = ptr + 1;
	ar.y = strtoul(l, &ptr, 10);
	if (ptr == l) {
		fprintf(stderr, "crop error, expected number at %s\n", l);
		return false;
	}
	if (*ptr != ' ') {
		fprintf(stderr, "crop error, expected ' ' at %s\n", ptr);
		return false;
	}
	l = ptr + 1;
	filename = l;
	return true;
}

void readCmd()
{
	using namespace std;
	string line, inputfile;
	alto_rectangle ar;
	block_cutter *pbc = 0;
	int ncrop = 0;
	int quality = -1;

	while (getline(cin, line)) {
		if (line.substr(0, 8) == "source: ") {
			delete pbc;
			pbc = new block_cutter();
			if (!pbc) {
				fprintf(stderr, "could not create blockcutter\n");
				exit(1);
			}
			if (quality > 0 && quality <= 100) {
				pbc->set_quality(quality);
			}
			ncrop = 0;
			if (line.length() > 8) {
				inputfile = line.substr(8);
			} else {
				fprintf(stderr, "no filename supplied for source file\n");
				exit(1);
			}
		} else if (line == "docrop") {
			if (pbc && ncrop) {
				pbc->cut_all(inputfile, 1.0f);
			} else if (!pbc) {
				fprintf(stderr, "no source file supplied for cropping operation\n");
				exit(1);
			} else {
				fprintf(stderr, "no regions to crop for cropping operation\n");
				exit(1);
			}
		} else if (line.substr(0, 5) == "crop ") {
			std::string fout;
			if (!parse_crop(line, ar, fout)) {
				exit(1);
			}
			if (!pbc) {
				fprintf(stderr, "no input filename supplied before crop command\n");
				exit(1);
			}
			ncrop++;
			pbc->add(ar, fout);
		} else if (line.substr(0, 9) == "quality: ") {
			const char *l = line.c_str() + 9;
			char *ptr; 
			quality = strtoul(l, &ptr, 10);
			if (ptr == l) {
				fprintf(stderr, "quality has to be numeric\n");
				exit(1);
			}
			if (quality < 1 || quality > 100) {
				fprintf(stderr, "quality value has to be between 1 <= quality <= 100 (%s)\n", line.c_str());
				exit(1);
			}
		} else {
			fprintf(stderr, "invalid command %s\n", line.c_str());
			exit(1);
		}
	}
}

int main(int argc, char **argv)
{
	if (argc > 1) {
		print_help();
		return 0;
	}
	readCmd();
	return 0;
}
