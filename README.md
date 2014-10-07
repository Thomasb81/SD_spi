SD_spi is a small project that read song from SD card in spi.

On SD Card a basic partitionning allows several song. All song should be referenced in the header.
The header is composed as follow:
Each entry is compose of 8 Bytes. The first entry is not used. Then each entry reprente a song.
The 4 first byte are the offset of the song. The next 4 second byte reprente the song length.

The song can be produce by such command
sox my_song.wav -b 16 out.wav rate 48k
sox out.wav --bits 16 --encoding unsigned-integer --endian little out2.raw

Then a header as describe must be stitch before out2.raw and the result file could be written on the SD card:

sudo dd if=card.bin of=/dev/sdb

Setup ttyUSBx interface to 3Mbps and following commands are recognized
0x85 0x01 : toggle up note on
0x85 0x00 : toggle down note on
0x86 0x01 : toggle up note off
0x86 0x00 : toggle down note off
0x87 0x0? : to select which song to play.
