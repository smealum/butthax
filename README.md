# butthax

This repository contains code for an exploit chain targeting the Lovense Hush connected buttplug and associated software. This includes fully functional exploit code for a Nordic Semiconductor BLE stack vulnerability affecting all versions of SoftDevices s110, s120 and s130, as well as versions of the s132 SoftDevice 2.0 and under.

Exploit details can be found in the slides for the associated DEF CON 27 talk, [Adventures in smart buttplug penetration (testing)](https://media.defcon.org/DEF%20CON%2027/DEF%20CON%2027%20presentations/DEFCON-27-smea-Adventures-in-smart-buttplug-penetration-testing.pdf).

## How to build

I don't really expect anyone to actually build this, but if for some reason you do, follow these steps:

1. Get [armips](https://github.com/Kingcom/armips/releases) (I used version 0.10.0) and have it in your PATH
2. Install [devkitARM](https://devkitpro.org/wiki/Getting_Started)
3. Get the buttplug's SoftDevice from Nordic ([s132_nrf52_1.0.0-3.alpha_softdevice.hex](https://www.nordicsemi.com/Software-and-Tools/Software/S132/Download#infotabs)) and place it in the inputbin directory (or dump it from your own plug)
4. Dump your buttplug's application firmware through SWD (for example with j-link command "savebin hushfw.bin, 1f000, 4B30") and place it as hushfw.bin in the inputbin directory
5. Run build.bat - it should generate exploitfw.zip. You can then use the Nordic Toolbox app to enable DFU mode on the target buttplug using the "DFU;" serial command and then flash the custom firmware you just built through the app's DFU functionality

NOTE: if anything goes wrong building this you could totally end up bricking your toy, or worse. So please be sure to 100% know what you're doing and don't blame me if it does mess up.

## Files

- **fwmod**: malicious firmware for the Hush
    - **firmwaremod.s**: edits the firmware to (a) install hooks into the softdevice that will allow us to intercept raw incoming/outgoing BLE packets and send (b) our own raw BLE packets
    - **exploit**
        - **source/main.c**: C implementation of the Nordic SoftDevice BLE vulnerability exploit
        - **source/payload.c**: binary payload to be sent to and run by the victim USB dongle
- **inputbin**: input binaries that i don't want to redistribute because i didn't make them and don't want to get in trouble (BYOB)
- **js/t.js**: JavaScript payload to run in the Lovense Remote app - downloads an EXE file, runs it, and then forwards the payload to everyone in the user's friend list
- **s132_1003a_mod**: modifications to the 1.0.0.3alpha version of the s132 SoftDevice (which is what the Hush ships with) which allow our modded firmware to interact with the BLE stack - must be built before fwmod
- **scripts**: various python scripts to help build this crap
- **shellcode**: a few assembly files for tiny code snippets used around the exploit chain - doesn't need to be built as they're already embedded in other places, only provided for reference
    - **flash.s**: source for *fwmod/exploit/source/payload.c*, ie the payload that runs on the victim USB dongle - contains code to generate the HTML/JavaScript payload, flash it to the dongle for persistence, and then send it over to the app

## Contact

You can follow me on twitter [@smealum](https://twitter.com/smealum) or email me at [smealum@gmail.com](mailto:smealum@gmail.com).

## Disclaimer

don't be a dick, please don't actually try to use any of this

