# Minux (maltalef's metadistribution of Arch Linux)
## Installation

Being on an Arch and Pacman based distribution as root, execute the following commands:

`curl -LO https://raw.githubusercontent.com/maltalef101/marbs/master/minux.sh
sh minux.sh`

Simple as that.

## What is Minux?
Minux is a shell script that installs a series of packages and configuration files that create a terminal/vim/tiling window manager-based Arch Linux metadistribution.

## What's the purpose of Minux?
The first purpose of Minux was to give myself some project that I could spend some time with and learn more about shell scripting. I ended up converting it into a full-fledged, community directed project. If I were in a café an someone came up to me and ask me what programs I was using to get this nice and cool desktop, I could easily direct them to this repository.

It's purpose now is to give the user a comfortable set of applications that they could use to learn more about the ins and outs of configuring and mantaining a GNU/Linux system. When switching to Arch, I saw this as a good opportunity for myself.

## The components:
### programs.csv
It's a conventional .csv file that serves the purpose of listing the programs that will be installed, and to inform the user about what each program does.

It's separated into three columns:

- The first one is a TAG that indicates the script how the package should be installed. `A` is for AUR, the Arch user repository. It's installed via yay. `G` is for git, packages that should be `make & sudo make install`ed.
- The second one is the package name.
- The third one is a description of the package, formatted in such a way that the package name is a noun and the description fits perfectly.

### minux.sh
The script is divided in very modular small bits of code that do one thing. Thus, it can be read and modifed easily.

All of the hard work is done by the `installLoop` function, that cycles through the programs files and decides, based on the tag of each program, which commands to exectue to install it. It's a simple case statement, you can easily add new installation methods.

Take note that programs from the AUR can **only** be installed by a non-root user. What Minux does to bypass this is to habilitate the new user to run commands as `sudo` without a password, such as the user won't be prompted for a password many many times during the installation.
I actually prefer, absolutely taking into considerations the security risks, running `sudo` without a password. You can change this editing the `/etc/sudoers` file.
#### Contact
Email: maltalef101@gmail.com
