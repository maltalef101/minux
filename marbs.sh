#! /bin/sh
# maltalef101's auto rice bootstrapping scripts (MARBS)
# ((idea copied from luke smith (i really did steal a lot of fucking shit from him), but remade slightly different as a personal shell scripting project))

# variables
progsfile="https://raw.githubusercontent.com/maltalef101/marbs/master/programs.csv"
IFS="
"
dotfilesrepo="https://github.com/maltalef101/dotfiles.git"
repobranch="master"

# print the initial message with all the information:
echo "<<     This script will install and configure the Arch Linux rice that I (maltalef101) have made.      >>"
echo "<<      It's made for, and in the best case scenario, only for, a fresh Arch linux installation.       >>"
echo "<<  If you only want my dotfiles, these are in my GitHub (https://github.com/maltalef101/dotfiles.git) >>"
echo "(This installation is really straight forward once you enter all of your information)"

if [ "$(whoami)" != "root" ]; then
   echo "Are you sure you're running as root?"
   exit 1
fi

# !!! FUNCTIONS !!!

confirm() {
    read -p "Do you wish to start the install? (y/n) " response1

    if [ $response1 = "y" -o $response1 = "Y" -o $response1 = "yes" -o $response1 = "Yes" ]; then
        read -p "Are you REALLY REALLY sure? This is your last chance to back out. (y/n) " response2

        if [ $response2 = "y" -o $response2 = "Y" -o $response2 = "yes" -o $response2 = "Yes" ]; then
           return 0
        else
           exit 1
        fi
    else
        exit 1
    fi
}

addUser() {
    read -p "First, please enter an username for your account: " username
    # checks for valid username
    while ! echo "$username" | grep "^[a-z_][a-z0-9_-]*$" >/dev/null 2>&1; do
        echo "Username not valid. Please enter a username beginning with a letter, with only lowercase letters, - or _"
        read -p "Enter your username: " username
    done

    # checks for existing user
    if [ "$(id -u $username > /dev/null 2>&1; echo $?)" != 1 ]; then
        echo "User '$username' already exists. MARBS will NOT override any personal files or documents, it will just override the configurations for the existing user and the password assigned for the one you will enter."
        read -p "Do you wish to continue? (y/n) " existingUserConfirm

        if [ $existingUserConfirm = "y" -o $existingUserConfirm = "Y" -o $existingUserConfirm = "yes" -o $existingUserConfirm = "Yes" ]; then
            useradd -m -g "wheel" "$username" >/dev/null 2>&1
            passwd "$username"
            echo "User with username '$username' modified."
        else
            exit 1
        fi
    else
        useradd -m -g "wheel" "$username" >/dev/null 2>&1
        passwd "$username"
        echo "User with username '$username' added."
    fi

    mkdir /home/$username/downloads
    mkdir /home/$username/documents
    mkdir /home/$username/pictures
    mkdir /home/$username/videos
}

refreshKeys() {
    echo "Refreshing Arch Keyring..."
    pacman --noconfirm -Sy archlinux-keyring >/dev/null 2&>1
}

manualInstall() { # Installs $1 manually if not installed. Used only for AUR helper here.
	[ -f "/usr/bin/$1" ] || (
	echo "Installing yay, an AUR helper."
	cd /tmp || exit
	rm -rf /tmp/"$1"*
	curl -sO https://aur.archlinux.org/cgit/aur.git/snapshot/"$1".tar.gz &&
	sudo -u "$username" tar -xvf "$1".tar.gz >/dev/null 2>&1 &&
	cd "$1" &&
    sudo -u "$username" makepkg --noconfirm -si >/dev/null 2>&1
    cd /tmp || return)
}

installLoop() {
    echo "!! PACKAGES WILL NOW BE INSTALLED !!"
    echo "This will take some time. Make sure to sit back and relax."
    curl -Ls "$progsfile" > /tmp/programs.csv
    progs="/tmp/programs.csv"
    for i in $(cat $progs); do
        total=$(wc -l $progs)
        installed=0

        echo "Installed $installed out of $total programs"

        tag=$(echo $i | awk -F "," '{print $1}' -)
        packet=$(echo $i | awk -F "," '{print $2}' -)

       if [ "$tag" = "A" ]; then
           sudo -u $username yay -S --noconfirm $packet
       else
           pacman -S --noconfirm --needed $packet
       fi

    done
}

putGitRepo() { # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
	echo "Downloading and installing config files..."
	[ -z "$3" ] && branch="master" || branch="$repobranch"
	dir=$(mktemp -d)
	[ ! -d "$2" ] && mkdir -p "$2"
	chown -R "$username":wheel "$dir" "$2"
	sudo -u "$username" git clone --recursive -b "$branch" --depth 1 "$1" "$dir" >/dev/null 2>&1
	sudo -u "$username" cp -rfT "$dir" "$2"
}

finalize() {
    echo "Finished! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place."
    echo "To run the new graphical enviroment, log out and log back in as your new user, and then run the command 'startx' to start the graphical enviroment (it will start automagically in tty1)."
}

# !!! PROGRAM LOGIC !!!
# this is where all the actual program order comes in place

confirm

addUser

pacman -S --noconfirm --needed curl
pacman -S --noconfirm --needed base-devel
pacman -S --noconfirm --needed git
pacman -S --noconfirm --needed ntp

echo "Updating system time to ensure successful and secure installation."
ntpdate 0.us.pool.ntp.org >/dev/null 2>&1

[ -f /etc/sudoers.pacnew ] && cp /etc/sudoers.pacnew /etc/sudoers # Just in case.

# Allow user to run sudo without password. AUR programs must be installed in a
# fakeroot enviroment. This is required with all builds that use AUR packages.
chmod 640 /etc/sudoers
sed -i "s/^# %wheel ALL=(ALL) NOPASSWD: ALL$/%wheel ALL=(ALL) NOPASSWD: ALL/" /etc/sudoers
chmod 0440 /etc/sudoers

# Make pacman and yay colorful and adds eye candy on the progress bar because why not.
grep "^Color" /etc/pacman.conf >/dev/null || sed -i "s/^#Color$/Color/" /etc/pacman.conf
grep "ILoveCandy" /etc/pacman.conf >/dev/null || sed -i "/#VerbosePkgLists/a ILoveCandy" /etc/pacman.conf

manualInstall yay

refreshKeys

installLoop

chsh -s /bin/zsh "$username"

putGitRepo "$dotfilesrepo" "/home/$username" "$repobranch"
rm -f "/home/$username/README.md"

# Last message. Install complete!
finalize
