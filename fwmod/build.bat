@echo off

cd exploit && make clean && make && cd ..
py -3 ../scripts/flashdiff.py > patchsoftdevice.s
armips firmwaremod.s
del .\exploitfw\exploitfw.bin
copy /b .\firmwaremod.bin .\exploitfw\exploitfw.bin
del exploitfw.zip
cd exploitfw && py -3 ../../scripts/gendfupkg.py exploitfw.bin exploitfw.dat manifest.json ../exploitfw.zip && cd ..
