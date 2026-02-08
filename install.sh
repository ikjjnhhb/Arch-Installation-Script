#!/bin/bash

exec setfont ter-132b

while true; do
    echo "Would you like to install Arch Linux? (yes/no)"
    read question
    if [ "$question" = yes ]; then
        echo "Are you using Wi-Fi? (yes/no)"
        read question
        if [ "$question" = yes ]; then
            echo "What is the name of your Wi-Fi?"
            read ssid
            iface=$(iw dev | awk '/Interface/ {print $2}')
            echo "What is your password of your Wi-Fi?"
            read pass
            wpa_supplicant -q -i "$iface" -c <(wpa_passphrase "$ssid" "$pass") &
            dhcpcd "$iface"
            break
        elif [ "$question" = no ]; then
            iface=$(ip -o link show | awk -F': ' '{print $2}' | grep -E '^e')
            dhcpcd "$iface"
            break
        else
            echo "Invalid Choice"
        fi
    elif [ "$question" = no ]; then
        echo "Exiting Installer"
        exit 0
    else
        echo "Invalid Choice"
    fi
done

echo "Do you want MBR or GPT partitioning? (MBR/GPT) (WARNING AFTER CHOOSING THIS INSTALLATION WILL START AND FORMAT THE WHOLE DISK)"
read parttype
if [ "$parttype" = "MBR" ]; then
    parted /dev/sda --script mklabel msdos
    parted /dev/sda --script mkpart primary linux-swap 1MiB 4GiB
    parted /dev/sda --script mkpart primary ext4 4GiB 100%
    mkswap /dev/sda1
    swapon /dev/sda1
    mkfs.ext4 /dev/sda2
    mount /dev/sda2 /mnt
elif [ "$parttype" = "GPT" ]; then
    parted /dev/sda --script mklabel gpt
    parted /dev/sda --script mkpart primary fat32 1MiB 513MiB
    parted /dev/sda --script set 1 esp on
    parted /dev/sda --script mkpart primary linux-swap 513MiB 4.5GiB
    parted /dev/sda --script mkpart primary ext4 4.5GiB 100%
    mkfs.fat -F32 /dev/sda1
    mkswap /dev/sda2
    swapon /dev/sda2
    mkfs.ext4 /dev/sda3
    mount /dev/sda3 /mnt
    mkdir -p /mnt/boot/efi
    mount /dev/sda1 /mnt/boot/efi
else
    echo "Invalid Choice, there are not any changes made to your current system."
    exit 1
fi

pacstrap /mnt base linux linux-firmware nano vim sudo
genfstab -U /mnt >> /mnt/etc/fstab
echo "KEYMAP=us" | tee /mnt/etc/vconsole.conf
echo "IUseArchBtw" | tee /mnt/etc/hostname

arch-chroot /mnt /bin/bash -c "
    pacman -Sy --noconfirm grub efibootmgr
    if [ \"$parttype\" = \"MBR\" ]; then
        grub-install --target=i386-pc /dev/sda
    elif [ \"$parttype\" = \"GPT\" ]; then
        grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
    fi
    grub-mkconfig -o /boot/grub/grub.cfg
    passwd
"
