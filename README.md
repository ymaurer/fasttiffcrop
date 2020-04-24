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
```

# How the fast cropping works
Suppose you would like to extract the red, yellow and green rectangles of the following TIFF to separate JPEG files.
![example image](https://user-images.githubusercontent.com/14054229/80147013-1b301e80-85b3-11ea-83e2-e2a4d419f47b.png)
Then fasttiffcrop will do the following:
1. Read the image header to find out width & height
2. Skip ahead until the first rectangle to extract starts. For uncompressed TIFF files, this means no data needs to be read from disk, for compressed TIFF files, some intermediate data has to be read and discarded. This skipping is indicated by the blue arrow.
3. Read the first scanline which contains the red and yellow rectangle. After the line from the TIFF is read, the red & yellow JPEG encoders get their pixels as needed.
![](https://user-images.githubusercontent.com/14054229/80148066-bfff2b80-85b4-11ea-8969-4fc4b0d643f9.png)
4. continue until the end of the yellow rectangle. At that point the JPEG for the yellow one is finished and that file can be closed. The green rectangle starts just afterwards. So open a new output JPEG for the green rectangle.
![](https://user-images.githubusercontent.com/14054229/80148059-becdfe80-85b4-11ea-9e28-ebafb45eed8c.png)
5. Then continue until the red rectangle is finished. Close the corresponding output JPEG file.
![](https://user-images.githubusercontent.com/14054229/80148062-bf669500-85b4-11ea-9d20-de4e4c1fce4a.png)
6. Finally, go until the green rectangle finished, close the green JPEG. At that point we don't need to do any more work, so close the TIFF as well.
![](https://user-images.githubusercontent.com/14054229/80148065-bfff2b80-85b4-11ea-96a8-38f0f569e157.png)

# Helper script
There is a helper script which can be used to extract parts of newspaper images from the open data at data.bnl.lu. That data uses the METS/ALTO Format and inside the ALTO files are the coordinates of the individual Words, Textlines, blocks, ilustrations etc. on the page.

*usage: gen-alto-cropping-script.sh directory [blocktype]*

`directory` is a directory which contains tif and alto files
the assumption is that the directory layout is the same as in data.bnl.lu's METS opendata that means that TIF files are in an 'images' subfolder and ALTO files are in a 'text' subfolder the filenames for tif and alto are the same, except the extensio

`blocktype` is the type of block that should be extracted. For ALTO, valid types are:
  - <TextBlock
  - <ComposedBlock
  - <String
  - <Textline
  - <Illustration
they can be combined with a pipe
default is <TextBlock|<Illustration

# Performance

- Extracting all TextBlocks from https://data.bnl.lu/open-data/digitization/newspapers/set03-1month.zip results in 6444 JPEG files. This is done in 39.142s on a i5 4670 with a Corsair M2 SSD. A total of 2571MB of TIFF files has to be considered and 467MB of JPG files are created.
