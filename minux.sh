#! /bin/sh
# maltalef101's auto rice bootstrapping scripts (Minux)
# ((idea copied from luke smith (i really did steal a lot of fucking shit from him), but remade slightly different as a personal shell scripting project))
# Licence: MIT

# variables
progsurl="https://raw.githubusercontent.com/maltalef101/minux/master/programs.csv"
dotfilesrepo="https://github.com/maltalef101/dotfiles.git"
repobranch="master"
IFS="
"
# Checks if root. If not, exits.
if [ "$(whoami)" != "root" ]; then
  echo "Are you sure you're running as root?"
  exit 1
fi

# Install "dialog" for the installation prompts.
pacman --noconfirm --needed -S "dialog" >/dev/null 2>&1

# !!! FUNCTIONS !!!

installPkg() { pacman --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}
aurInstall() { sudo -u $username yay --noconfirm --needed -S "$1" >/dev/null 2>&1 ;}
pipInstall() { sudo pip install "$1" >/dev/null 2>&1 ;}

welcomeMsg() {
  dialog --title "-- Minux instllation --" --msgbox "Welcome to Minux!\nThis script will install and configure the Arch Linux rice that I (maltalef101) have made.\n\nIt's made for, and in the best case scenario, only for, a fresh Arch Linux installation.\n\nIf you only want my dotfiles, they are in my GitHub (https://github.com/maltalef/dotfiles.git)" 14 65
  dialog --color --title "!! IMPORTANT NOTE !!" --infobox "Make sure you have the latest version of pacman installed or the installation process of some packages will most certainly fail." 7 65
}

getUserAndPass() {
  # Gets username and password
  username=$(dialog --inputbox "Enter a username for your new user account." 10 60 3>&1 1>&2 2>&3 3>&1) || exit

  # Checks for valid username
  while ! echo "$username" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
    username=$(dialog --inputbox "Username invalid. Please enter a username beginning with a letter, with only lowercase letters, - or _" 10 60 3>&1 1>&2 2>&3 3>&1)
  done

  # Gets password
  pass1=$(dialog --no-cancel --passwordbox "Now, enter a password for that user." 10 60 3>&1 1>&2 2>&3 3>&1)
  pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
  # Checks if the two passwords are the same
  while [ "$pass1" != "$pass2" ]; do
    unset pass2
    pass1=$(dialog --no-cancel --passwordbox "Passwords do not match.\n\nEnter password again."10 60 3>&1 1>&2 2>&3 3>&1)
    pass2=$(dialog --no-cancel --passwordbox "Retype password." 10 60 3>&1 1>&2 2>&3 3>&1)
  done
}

checkUser() {
  if [ "$(id -u $username >/dev/null 2>&1; echo $?)" != 1 ]; then
    dialog --title "-- Minux installation --" --yes-label "Yes, continue." --no-label "No! Go back" --yesno "User '$username' already exists, if you continue, your login credentials will be overwritten, as well as your config files if you then chose to continue with the installation.\n\nDo you wish to continue?" 10 60
  fi
}

preInstallConfirm() {
    dialog --title "-- Minux installation --" --yes-label "Yes, continue." --no-label "No! Go back" --yesno "This is your last chance to back out.\n\nDo you wish to continue with the installation?" 10 60
	[ "$(echo $?)" -eq 1 ] exit 1
}

addUser() {
# Adds user `$name` with password $pass1.
	dialog --infobox "Adding user \"$username\"..." 4 50
	useradd -m -g wheel "$username" >/dev/null 2>&1 ||
	usermod -a -G wheel "$username" && mkdir -p /home/"$username" && chown "$username":wheel /home/"$username"
	repodir="/home/$username/.local/src"; mkdir -p "$repodir"; chown -R "$username":wheel "$(dirname "$repodir")"
	echo "$username:$pass1" | chpasswd
	unset pass1 pass2
}

refreshKeys() {
	echo "Refreshing keyring..."
	case "$(readlink -f /sbin/init)" in
	  *systemd*) pacman --noconfirm -Sy archlinux-keyring >/dev/null 2&>1 ;;
	  *openrc*) pacman --noconfirm -Sy artixlinux-keyring >/dev/null 2&>1 ;;
	esac
}

gitMakeInstall() {
  progname=$(basename "$1" ".git")
  dir="$repdir/$progname"

  mkdir -p /home/$username/.local/share/src/
  cd /home/$username/.local/src/
  git clone $1
  cd $dir
  make
  make install
  cd $HOME
}

manualInstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	dialog --title "-- Minux installation --" --infobox "Installing 'yay'. yay is an AUR helper. It works as a pacman wrapper for installing packages from the AUR." 7 60
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$username" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
    sudo -u "$username" makepkg --noconfirm -si >/dev/null 2>&1
    cd /tmp || return)
}

installLoop() {
  dialog --title "-- Minux installation --" --infobox "Packages will now be installed!\n\nThis will take some time. Be sure to grab a drink, a book, sit back, and relax." 7 60
  progs="/tmp/progrsms.csv"
  curl -Ls "$progsurl" > $progs
  rem=$(head -1 "$progs")
  total=$(wc -l "$progs")
  installed=1

  for i in $(grep -v "$rem" "$progs"); do
    tag=$(echo $i | awk -F "," '{print $1}' -)
    pkgname=$(echo $i | awk -F "," '{print $2}' -)
    pkgdesc=$(echo $i | awk -F "," '{print $3}' - | tr '"' '\b')

    dialog --title "-- Minux instllation --" --infobox "Installing '$pkgname'. $pkgname  $pkgdesc\n\n$installed out of $total packages installed." 8 60

    case $tag in
      "A") aurInstall "$pkgname" ;;
      "G") gitMakeInstall "$pkgname" ;;
	  "P") pipInstall "$pkgname" ;;
      *) installPkg "$pkgname" ;;
    esac
    installed=$((installed+1))
  done
}

putGitRepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
  dialog --title "-- Minux installation --" --infobox "Dotfiles downloading and installation in progress." 5 60
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$username":wheel "$dir" "$2"
	sudo -u "$username" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$username" cp -rfT "$dir" "$2"
}

disableMouseAccel () {
	dialog --title "-- Minux installation --" --infobox "Disabling mouse acceleration" 5 60
	mkdir -p /etc/X11/xorg.conf.d/
	echo "Section "InputClass"
	Identifier "My Mouse"
	Driver "libinput"
	MatchIsPointer "yes"
	Option "AccelProfile" "flat"
	Option "AccelSpeed" "0"
EndSection" > /etc/X11/xorg.conf.d/50-mouse-acceleration.conf
}

finalize() {
  dialog --title "-- Minux installation --" --msgbox "Finished!\n\nProvided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\n\nTo run the new graphical enviroment, log out and log back in as your new user, and then run the command 'startx' to start the graphical enviroment (it will start automagically in tty1)." 15 70
}

# !!! PROGRAM LOGIC !!!
# this is where all the actual program order comes in place

# welcomes the user with a nice little message.
welcomeMsg

# asks the user for the desired username and password
getUserAndPass

# checks if the user actually exists an prompts the user for confirmation
checkUser

# prompts the user for confirmation on the installation. this is the user's last chance to back out.
preInstallConfirm

# actually adds the entered username and password
addUser

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

# Refreshes arch keyring because gpg signing is ballin.
refreshKeys

installPkg curl
installPkg base-devel
installPkg git
installPkg ntp

dialog --title "-- Minux installation --" --infobox "Updating system time to ensure successful and secure installation of packages..." 5 60
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case.

# Allow user to run sudo without password. AUR programs must be installed in a
# fakeroot enviroment. This is required with all builds that use AUR packages.
chmod 640 /etc/sudoers
sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
chmod 0440 /etc/sudoers

# installs yay manually, 'makepkg -si' style
manualInstall yay

# THIS IS THE FUNCTION CALL THAT ACTUALLY INSTALLS ALL
# OF THE PACKAGES IN THE .csv
# IF YOU WANT TO CHANGE SOMETHING ABOUT THIS, THE
# FUNCTION IS DEFINED ABOVE.
installLoop

# use all cores for compilation, this could make a difference on large programs but idk
sed -i "s/-j2/-j$(nproc)/:s/^#MAKEFLAGS/MAKEFLAGS" /etc/makepkg.conf

# installs libxft-bgra to enable emojis and stuff on suckless software without crashes
aurInstall "libxft-bgra"

# puts the git repo on the users home directory
putGitRepo "$dotfilesrepo" "/home/$username" "$repobranch"
rm -f "/home/$username/README.md"
# make git ignore the deleted files
git update-index --asume-unchanged "/home/$username/README.md"

# removing beep because it SUCKS MASSIVE COCK
dialog --infobox "beeping sucks ass.\nremoving module" 5 50
rmmod pcspkr
echo "blacklist pcspkr" > /etc/modprobe.d/nobeep.conf

# disable mouse acceleration (or actually, enable a flat profile for it, but technicisms, man)
disableMouseAccel

# changes default shell to zsh because bash is doodoo.
chsh -s /bin/zsh "$username" >/dev/null 2>&1
sudo -u "$username" mkdir -p "/home/$username/.cache/zsh/"

# add user directories
mkdir /home/$username/downloads
mkdir /home/$username/documents
mkdir /home/$username/pictures
mkdir /home/$username/videos
mkdir /home/$username/public
mkdir /home/$username/music
mkdir /home/$username/templates
mkdir /home/$username/Desktop

# dbus UUID is required for Artix installations with runit
dbus-uuidgen > /var/lib/dbus/machine-id

# Last message. Install complete!
finalize
