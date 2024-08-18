#!/bin/bash

# Check if the required number of arguments is provided
if [ "$#" -lt 3 ]; then
    echo "Usage: $0 <name-output-iso> <packages> <iso-url>"
    exit 1
fi

# Assign arguments to variables
ISO_OUTPUT="$1"
shift
PACKAGES="$1"
shift
ORIGINAL_ISO="$1"

# Set some variables
WORKDIR=$(mktemp -d)
LOGFILE="/usr/src/app/isos/${ISO_OUTPUT}.log"

# Function to log progress
log_progress() {
    echo "$1" >> "$LOGFILE"
}

# Start logging
log_progress "0%: Starting ISO creation"

# Ensure necessary tools are installed
log_progress "5%: Ensuring necessary tools are installed"
sudo apt-get update
sudo apt-get install -y squashfs-tools genisoimage rsync wget

# Download the specified ISO if not already present
ISO_FILENAME=$(basename "$ORIGINAL_ISO")
if [ ! -f "$ISO_FILENAME" ]; then
    log_progress "10%: Downloading Ubuntu ISO from $ORIGINAL_ISO"
    wget "$ORIGINAL_ISO"
fi

# Check if the ISO file was downloaded successfully
if [ ! -f "$ISO_FILENAME" ]; then
    log_progress "Error: ISO file not found"
    exit 1
fi

# Mount the original ISO
log_progress "15%: Mounting the original ISO"
mkdir -p "$WORKDIR/mount"
sudo umount "$WORKDIR/mount" 2>/dev/null || true
if ! sudo mount -o loop "$ISO_FILENAME" "$WORKDIR/mount"; then
    log_progress "Error: Failed to mount ISO"
    exit 1
fi

# Copy the contents of the ISO to a new directory
log_progress "20%: Copying contents of the ISO"
mkdir -p "$WORKDIR/extract-cd"
rsync --exclude=/casper/filesystem.squashfs -a "$WORKDIR/mount/" "$WORKDIR/extract-cd"

# Check if the filesystem.squashfs file exists
if [ ! -f "$WORKDIR/mount/casper/filesystem.squashfs" ]; then
    log_progress "Error: filesystem.squashfs not found"
    sudo umount "$WORKDIR/mount"
    exit 1
fi

# Extract the filesystem
log_progress "30%: Extracting the filesystem"
mkdir -p "$WORKDIR/squashfs-root"
sudo rm -rf "$WORKDIR/squashfs-root"
sudo unsquashfs -d "$WORKDIR/squashfs-root" "$WORKDIR/mount/casper/filesystem.squashfs"

# Ensure /bin/bash exists in the chroot environment
if [ ! -f "$WORKDIR/squashfs-root/bin/bash" ]; then
    log_progress "Error: /bin/bash not found in chroot environment"
    exit 1
fi

# Bind mount /proc, /sys, /dev, /usr, and /run to the chroot environment
log_progress "40%: Preparing chroot environment"
for dir in dev dev/pts proc sys usr run; do
    sudo mkdir -p "$WORKDIR/squashfs-root/$dir"
    sudo mount --bind /$dir "$WORKDIR/squashfs-root/$dir"
done

# Chroot into the environment
log_progress "50%: Chrooting into environment and installing packages"
cat <<EOF | sudo chroot "$WORKDIR/squashfs-root"
mount -t proc none /proc
mount -t sysfs none /sys
mount -t devpts none /dev/pts
export HOME=/root
export LC_ALL=C

# Install selected packages
apt-get update
apt-get install -y $PACKAGES

# Update initramfs
update-initramfs -u

# Clean up
apt-get clean
umount /proc || umount -lf /proc
umount /sys
umount /dev/pts
exit
EOF

# Unmount the chrooted filesystems
log_progress "70%: Unmounting chrooted filesystems"
for dir in dev/pts dev proc sys usr run; do
    sudo umount "$WORKDIR/squashfs-root/$dir"
done

# Repack the filesystem
log_progress "80%: Repacking the filesystem"
sudo mksquashfs "$WORKDIR/squashfs-root" "$WORKDIR/extract-cd/casper/filesystem.squashfs"

# Update the manifest
log_progress "85%: Updating the manifest"
if ! sudo chroot "$WORKDIR/squashfs-root" dpkg-query -W --showformat='${Package} ${Version}\n' | sudo tee "$WORKDIR/extract-cd/casper/filesystem.manifest"; then
    log_progress "Error: Failed to create filesystem.manifest"
    exit 1
fi
sudo cp "$WORKDIR/extract-cd/casper/filesystem.manifest" "$WORKDIR/extract-cd/casper/filesystem.manifest-desktop"

# Remove unnecessary packages from the manifest
sudo sed -i '/ubiquity/d' "$WORKDIR/extract-cd/casper/filesystem.manifest-desktop"
sudo sed -i '/casper/d' "$WORKDIR/extract-cd/casper/filesystem.manifest-desktop"

# Create the output directory for the ISO if it doesn't exist
mkdir -p /usr/src/app/isos

# Ensure the necessary files exist
if [ ! -f "$WORKDIR/extract-cd/isolinux/isolinux.bin" ]; then
    log_progress "Error: Missing isolinux.bin file"
    sudo umount "$WORKDIR/mount"
    exit 1
fi

if [ ! -d "$WORKDIR/extract-cd/casper" ]; then
    log_progress "Error: Missing casper directory"
    sudo umount "$WORKDIR/mount"
    exit 1
fi

# Copy initrd and vmlinuz
sudo cp "$WORKDIR/squashfs-root/boot/initrd.img-*" "$WORKDIR/extract-cd/casper/initrd"
sudo cp "$WORKDIR/squashfs-root/boot/vmlinuz-*" "$WORKDIR/extract-cd/casper/vmlinuz"

# Create the new ISO
log_progress "90%: Creating the new ISO"
cd "$WORKDIR/extract-cd"
if ! sudo mkisofs -D -r -V "Custom Ubuntu" -cache-inodes -J -l \
  -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -boot-load-size 4 -boot-info-table \
  -o "/usr/src/app/isos/$ISO_OUTPUT" .; then
    log_progress "Error: Failed to create ISO"
    sudo umount "$WORKDIR/mount"
    exit 1
fi

# Clean up
cd -
log_progress "95%: Cleaning up"
sudo umount "$WORKDIR/mount"
rm -rf "$WORKDIR"

log_progress "100%: ISO creation completed"
echo "New ISO created: /usr/src/app/isos/$ISO_OUTPUT"
