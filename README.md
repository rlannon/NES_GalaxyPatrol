# NES_GalaxyPatrol

Galaxy Patrol is my first attempt at a homebrew NES game, written entirely in 6502 assembly. It was/is being built with NESASM and debugged with FCEUX, both free tools for NES development and emulation.
I'm using the open source game _Galaxy Patrol_ from the [NESDev Wiki](https://wiki.nesdev.com/w/index.php/Nesdev_Wiki) for my inspiration and guide to better familiarize myself with NES programming before I dive in to more original projects.

## Getting Started

To build the project for yourself, you will need NESASM. I have included the windows version with the project.

If you do not have NESASM, it is [available on GitHub](https://github.com/toastynerd/nesasm) from multiple different pages and on multiple platforms. [This one, for example,](https://github.com/camsaul/nesasm) has a makefile for Mac OSX and other Unix-like systems.

If you are not familiar with 6502 assembly, [Nick Morgan has a great tutorial on GitHub to get you started](http://skilldrick.github.io/easy6502). The [Nerdy Nights Tutorials](http://nintendoage.com/forum/messageview.cfm?catid=22&threadid=7155) are great resources for learning NES programming, and the [Nesdev wiki](http://wiki.nesdev.com/w/index.php/Nesdev_Wiki) serves as a great programming and hardware reference.

You can check the wiki for a walkthrough of the code and more information about assembly programming for the NES.

### Windows

It is fairly easy to build the project on a Windows machine. Once galaxypatrol.asm, tiles.chr, build.bat, and nesasm.exe are in the same folder, simply run build.bat and a command prompt window will open. This will run NESASM and build a .nes file from the source code, which can be opened in any NES Emulator.
The batch file contains only two lines:

`NESASM3 some_assembly_file.asm`
`pause`

You can build from command prompt, but having the batch file is easier. If you choose to use a batch file, it is important to incldue the pause in order to see any errors you may get upon assembly.

### UNIX/Linux

Building a .nes file in UNIX/Linux is also easy, and you can follow the same sort of procedure as on windows. Once you have the Linux version of NESASM, simply type the following in your command line (assuming NESASM and your .asm file are in the same directory):

`./nesasm3 some_assembly_file.asm`

## Built With

- [Visual Studio Code](https://code.visualstudio.com/) - text editor
- NESASM3 - to make .nes files from assembly
- FCEUX - NES emulator

## Authors

- _Riley Lannon_ - Programmer and debugger

## License

This project is licensed under the MIT License - see LICENSE.md for more details.

## Acknowledgements

* Nerdy Nights -- this project would not have been possible if it weren't for the tutorials there
* NESDev wiki and subreddit -- the wiki and subreddit helped me greatly when I had questions during this project
