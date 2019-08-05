cls
md  release
del release\*.* /Q
del release\maze.exe

tasm maze3d.asm
tlink maze3d.obj, maze.exe

pklite maze.exe     release\maze.exe
copy texture.tga release\
copy map.bin     release\