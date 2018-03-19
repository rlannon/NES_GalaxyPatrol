# NES_GalaxyPatrol

Galaxy Patrol is my first attempt at a homebrew NES game, written entirely in 6502 assembly, built with NESASM and debugged with FCEUX.
I'm using the open source game _Galaxy Patrol_ from the [NESDev Wiki](https://wiki.nesdev.com/w/index.php/Nesdev_Wiki) for my inspiration and guide to better familiarize myself with NES programming before I dive in to more original projects.

## Getting Started

To build the project for yourself, you will need NESASM. I have included the windows version with the project.

If you do not have NESASM, it is [available on GitHub](https://github.com/toastynerd/nesasm) from multiple different pages. [This one](https://github.com/camsaul/nesasm) has a makefile for Mac OSX and other Unix or Unix-like systems.

If you are not familiar with 6502 assembly, [Nick Morgan has a great tutorial on GitHub to get you started](http://skilldrick.github.io/easy6502). The [Nerdy Nights Tutorials](http://nintendoage.com/forum/messageview.cfm?catid=22&threadid=7155) are also great resources for learning NES programming.

### Windows

It is fairly easy to build the project on a Windows machine. Once galaxypatrol.asm, tiles.chr, build.bat, and nesasm.exe are in the same folder, simply run build.bat and a command prompt window will open. This will run NESASM and build a .nes file from the source code, which can be opened in any NES Emulator.
The BATCH file contains only two lines:

`NESASM3 some_assembly_file.asm`
`pause`

You can build from command prompt, but having the BATCH file is easier in my opinion.

### UNIX/Linux

Building a .nes file in UNIX/Linux is also easy, and you can follow the same sort of procedure as on windows. Once you have the Linux version of NESASM, simply type the following in your command line (assuming NESASM and your .asm file are in the same directory):

`./nesasm3 some_assembly_file.asm`