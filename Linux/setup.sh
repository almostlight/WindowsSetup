#! /bin/bash

VM_NAME=$(sudo virsh list --all --name | grep -i "win")
DIR="$(dirname $(realpath $0))"
BIN_DIR="$HOME/.local/bin"
TARGET="$HOME/.local/share/applications/looking-glass-${VM_NAME}.desktop"
ICON_TARGET="$HOME/.local/share/icons/looking-glass-${VM_NAME}.svg"
LAUNCHER_TARGET="$BIN_DIR/looking-glass-${VM_NAME}"

chmod +x "$DIR"/*.sh

if [[ -f "$TARGET" ]]; then
    read -p "File '$TARGET' already exists. Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Operation cancelled."
        exit 1
    fi
fi

mkdir -p "$(dirname "$TARGET")"
mkdir -p "$(dirname "$LAUNCHER_TARGET")"
mkdir -p "$(dirname "$ICON_TARGET")"
cp -f "$DIR/logo.svg" "$ICON_TARGET"
cp -f "$DIR/launch_vm.sh" "$LAUNCHER_TARGET"
cp -f "$DIR/fix_libvirt_nat.sh" "$BIN_DIR/fix-libvirt-nat"
# rsvg-convert -w 48 -h 48 "$ICON" -o "$ICON_TARGET.xmp"
# chmod 777 "$ICON_TARGET.xmp"

# black magic with rev: https://unix.stackexchange.com/a/617832
echo "
[Desktop Entry]
Name=Windows 11 (Looking Glass)
Comment=Launch Windows 11 VM with Looking Glass
Exec=$LAUNCHER_TARGET
Icon=$(realpath $ICON_TARGET |rev| cut -d"." -f2- |rev)
Terminal=false
# Terminal=true
Type=Application
Categories=System;Emulator;
StartupNotify=true
StartupWMClass=looking-glass-client
" | tee $TARGET > /dev/null 2>&1

sudo usermod -aG libvirt,kvm "$(whoami)"
# Passwordless sudo configuration for virsh (optional)
echo "To allow passwordless VM start/shutdown, run:"
echo "sudo EDITOR=vim visudo"
echo "Then add the line:"
echo "$USERNAME ALL=(root) NOPASSWD: /usr/bin/virsh"

sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11 && \
	sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/prepare/begin && \
	sudo mkdir -p /etc/libvirt/hooks/qemu.d/win11/release/end

sudo cp -f "$DIR/vm_start.sh"			"/etc/libvirt/hooks/qemu.d/win11/prepare/begin/10-asusd-vfio.sh"
sudo cp -f "$DIR/hugepages_start.sh"	"/etc/libvirt/hooks/qemu.d/win11/prepare/begin/20-reserve-hugepages.sh"
sudo cp -f "$DIR/vm_stop.sh"			"/etc/libvirt/hooks/qemu.d/win11/release/end/40-asusd-integrated.sh"
sudo cp -f "$DIR/hugepages_stop.sh"		"/etc/libvirt/hooks/qemu.d/win11/release/end/10-release-hugepages.sh"

sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/prepare/begin/10-asusd-vfio.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/release/end/40-asusd-integrated.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/prepare/begin/20-reserve-hugepages.sh
sudo chmod +x /etc/libvirt/hooks/qemu.d/win11/release/end/10-release-hugepages.sh

# update grub driver loading
grep -q 'nvidia_drm.modeset=1' /etc/default/grub || \
	sed -i 's/^\(GRUB_CMDLINE_LINUX_DEFAULT="[^"]*\)"/\1 splash rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia_drm.modeset=1"/' /etc/default/grub
grep -q 'GRUB_CMDLINE_LINUX_DEFAULT' /etc/default/grub || \
	echo 'GRUB_CMDLINE_LINUX_DEFAULT="splash rd.driver.blacklist=nouveau,nova_core modprobe.blacklist=nouveau,nova_core nvidia_drm.modeset=1"' >> /etc/default/grub

update-grub

sudo usermod -aG libvirt,kvm "$(whoami)"
supergfxctl -m Vfio

echo "Setup complete! You can now launch Windows 11 via your application menu."

