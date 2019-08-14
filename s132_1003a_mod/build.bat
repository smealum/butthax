@echo off
python ../scripts/hexpack.py unpack ../inputbin/s132_nrf52_1.0.0-3.alpha_softdevice.hex
armips mod.s
python ../scripts/hexpack.py pack 0 ../inputbin/s132_nrf52_1.0.0-3.alpha_softdevice.hex_unpacked_00000000.bin 3000 mod.bin > s132_nrf52_1.0.0-3.alpha_softdevice_mod.hex
