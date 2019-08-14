import sys
import subprocess
import struct
from PyCRC.CRCCCITT import CRCCCITT

bin_fn = sys.argv[1]
dat_fn = sys.argv[2]
manifest_fn = sys.argv[3]
out_fn = sys.argv[4]

crc = CRCCCITT(version="FFFF").calculate(open(bin_fn, "rb").read())
dat_data = b"\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\x01\x00\xFE\xFF" + struct.pack("<H", crc)

open(dat_fn, "wb").write(dat_data)
open(manifest_fn, "w").write("""{
    "manifest": {
        "application": {
            "bin_file": "exploitfw.bin",
            "dat_file": "exploitfw.dat",
            "init_packet_data": {
                "application_version": 4294967295,
                "device_revision": 65535,
                "device_type": 65535,
                "firmware_crc16": 64126,
                "softdevice_req": [
                    65534
                ]
            }
        },
        "dfu_version": 0.5
    }
}
""")

subprocess.check_output(["C:\\Program Files\\7-Zip\\7z.exe", "a", out_fn, bin_fn, dat_fn, manifest_fn])
