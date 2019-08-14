@echo off

if exist "inputbin/s132_nrf52_1.0.0-3.alpha_softdevice.hex" (
	if exist "inputbin/hushfw.bin" (
		cd s132_1003a_mod && call build.bat && cd ..
		cd fwmod && call build.bat && cd ..
		move .\fwmod\exploitfw.zip .\exploitfw.zip
	) else (
		echo "Please dump the application firmware binary (savebin hushfw.bin, 1f000, 4B30) and place it in the inputbin directory."
	)
) else (
	echo "Please download s132_nrf52_1.0.0-3.alpha_softdevice.hex from Nordic's servers and place it in the inputbin directory."
)
