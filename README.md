# fastTiffCrop
This project is aimed at a very special use case when you have large TIFF files where you would like to crop out several regions as JPG.

## fasttiffcrop
This executable lets you quickly crop several rectangular regions as JPEGs from a single source TIFF file. It's optimized for speed and memory usage. Only a single scanline of TIFF content is held in memory at a time and JPEGs are written as soon as full blocks are available. The executable doesn't take command-line arguments but has a script-based interface. It takes its arguments through stdin and performs the operation on the "docrop" command. After a "docrop", you can restart with a new source image.

```
example usage:
source: blah.tiff
crop WxH+X+Y out1.jpg
crop WxH+X+Y out2.jpg
docrop
source: xxx.tiff
...
docrop

optionally, you may specify a JPEG quality (1 - 100) at any point. It will apply to the next docrop operation
quality: QQ
```

## tiff2jpg
Converts a TIFF to JPEG and optionally sets the quality and convert to greyscale. It's optimized for speed and memory usage. Only a single scanline of TIFF content is held in memory at a time and the JPEG blocks are written as soon as they are available.
```
usage: tiff2jpg [-quality QQ] [-color true|false] source dest
QQ is between 1 and 100
color is false by default, this means that the jpeg is greyscale
```

## Building
You need gcc, jpeg-6b headers and tiff 3.8.2 headers. An example makefile is given.
```sh
make
make install
```
