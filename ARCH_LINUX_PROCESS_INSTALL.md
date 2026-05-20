Comprehensive ThinkPad T14 Gen 6 (AMD) Arch Linux Installation Playbook
From Bare Metal (Ventoy & BIOS) to Automated Btrfs Snapshots (Snapper)
User Profile Target: carael

Architecture Spec: Agnostic Flat Btrfs, Native Systemd-Networkd, Minimal Disconnected Desktop Framework

Phase 1: Installation Media Preparation (Ventoy)
Instead of using traditional imaging tools like dd or Rufus which completely overwrite a flash drive's filesystem container, Ventoy injects a bootable storage manager directly into the drive's master boot record. This allows you to store normal files and simply drag-and-drop multiple installation ISOs onto the drive without re-formatting.

1. Install Ventoy to a USB Flash Drive
Download the latest Ventoy extraction archive on an existing system and identify your USB flash drive's hardware path using lsblk (e.g., /dev/sda). Run the installation utility:

Bash
sudo ./Ventoy2Disk.sh -i /dev/sda
Why: The -i command partitions the flash drive into two sections: a hidden, isolated EFI boot partition containing Ventoy’s GRUB driver modules, and a large exFAT partition for storage.

2. Stage the Operating System Image
Download the official archlinux-*.iso file from a trusted mirror. Copy the file directly onto the main visible exFAT partition of the USB drive using your standard file manager or terminal:

Bash
cp archlinux-*.iso /run/media/user/Ventoy/
Why: When the laptop boots, Ventoy dynamically hooks into this raw ISO file and mounts it directly as a virtual optical disc drive in system memory.

Phase 2: ThinkPad Hardware & UEFI BIOS Configuration
Modern Lenovo ThinkPad motherboards contain specialized security processors and aggressive energy management defaults that must be calibrated to prevent boot failures or hardware performance throttling under Linux.

Turn on the laptop and repeatedly tap the F1 (or Fn + F1) key to enter the firmware configuration panel. Apply the following adjustments:

1. Security Settings
Secure Boot ➔ Disabled

Why: The default Arch Linux live installation media and standard GRUB installations do not carry an out-of-the-box Microsoft digital signature. Leaving this enabled causes an immediate hardware firmware fallback error ("Security Violation").

Microsoft Pluton Security Processor ➔ Configured / Subsystem Logging Disabled

Why: Disabling the deep logging subsystems prevents the Linux kernel from spamming ACPI interrupt errors across your terminal lines during operation.

2. Configuration Settings
Power ➔ Sleep State ➔ Linux / Windows and Linux (Modern Standby)

Why: Forces the AMD system-on-chip to use low-power hardware deep states (s2idle). This prevents the system from staying fully active and overheating when the laptop lid is shut in a backpack.

Display ➔ UMA Frame Buffer Size ➔ 2G or 4G

Why: Allocates a guaranteed pool of your fast system RAM exclusively to the integrated Radeon graphics processor. This ensures that graphics-intensive tiling environments, local window compositions, and web browser hardware accelerations do not starve for memory during microservice loads.

Virtualization ➔ AMD SVM Technology & IOMMU ➔ Enabled

Why: Enables hardware-assisted virtualization. This is mandatory for running rootless Docker layers, isolated system sandboxes, and secure developer micro-containers at native execution speeds.

Press F10 to save your configurations and restart the machine. Tap F12 during startup to access the boot menu, choose your Ventoy USB drive, and select the Arch Linux Installation ISO.

Phase 3: Drive Partitioning & Advanced Btrfs Layout
Once dropped into the live Arch terminal, verify your high-speed 2TB NVMe drive identity:

Bash
lsblk
(This guide assumes your primary target disk is identified as /dev/nvme0n1)

1. Initialize the Partition Layout
Run the advanced GPT partition manager:

Bash
gdisk /dev/nvme0n1
Execute these configuration commands in order:

Type o and press Enter to write a fresh, clean GUID Partition Table (GPT) to the flash controller.

Type n ➔ Partition 1 ➔ First Sector: Default ➔ Last Sector: +1G ➔ Hex Code: EF00 (EFI System Partition).

Type n ➔ Partition 2 ➔ First Sector: Default ➔ Last Sector: Default (Rest of the disk) ➔ Hex Code: 8300 (Linux Native Container).

Type w and press Enter to permanently execute the partition table to the controller.

2. Formatter Initialization
Format the primary boot partition to FAT32 and the main system space to a native Btrfs container:

Bash
mkfs.vfat -F 32 /dev/nvme0n1p1
mkfs.btrfs -L ARCH_SYSTEM /dev/nvme0n1p2
Why: The motherboard's UEFI bootloader can only read basic FAT32 filesystems to locate boot binaries. The secondary data space is formatted as Btrfs to support instantaneous Copy-on-Write snapshots and advanced subvolume isolation.

3. Subvolume Architecture Mapping
To build a highly robust environment, we avoid nested subvolumes. Instead, we create a flat architecture at the root level of the drive partition:

Bash
# Temporarily mount the raw storage space
mount /dev/nvme0n1p2 /mnt

# Generate structural subvolume boundaries
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@data

# Safely unmount the raw storage container
umount /mnt
Why This Layout Matters: > * @ acts as your operating system root. If a system update corrupts your configurations, this subvolume can be rolled back independently.

@home isolates user configurations.

@snapshots holds backup points securely outside your operating layers.

@data serves as your universal, decoupled project vault. You can destroy or replace the entire operating system root (@) without touching your repositories, databases, or local data inside @data.

4. Optimize and Mount the Subvolumes
Mount the isolated virtual spaces back into position using flash-optimized operational flags:

Bash
# Mount the core system root
mount -o subvol=@,rw,noatime,compress=zstd:3,discard=async /dev/nvme0n1p2 /mnt

# Generate physical anchor directories
mkdir -p /mnt/{boot,home,.snapshots,data}

# Mount secondary virtual boundaries and hardware configurations
mount -o subvol=@home,rw,noatime,compress=zstd:3,discard=async /dev/nvme0n1p2 /mnt/home
mount -o subvol=@snapshots,rw,noatime,compress=zstd:3,discard=async /dev/nvme0n1p2 /mnt/.snapshots
mount -o subvol=@data,rw,noatime,compress=zstd:3,discard=async /dev/nvme0n1p2 /mnt/data

# Mount the physical hardware boot sector
mount /dev/nvme0n1p1 /mnt/boot
Why These Options Are Used:

noatime: Stops the kernel from writing data metadata updates every single time a script or application reads a file. This reduces redundant SSD writes.

compress=zstd:3: Activates transparent background ZSTD compression. This reduces file sizes on disk, extends NVMe life, and speeds up read operations since fewer blocks need to be physically processed.

discard=async: Enables continuous, asynchronous TRIM operations. This tells the controller which blocks are empty in the background, keeping write performance high over time.

Phase 4: Core System Bootstrapping
With the physical storage array constructed, inject the core Linux components and operational systems directly into your mounted directories.

1. Pacstrap Core Deployments
Bash
pacstrap -K /mnt base linux linux-lts linux-firmware sof-firmware btrfs-progs nano git openssh
Why This Package Matrix?

linux & linux-lts: Installs both the cutting-edge performance kernel and a Long Term Support kernel. If a new kernel update introduces a stability conflict with your hardware, you can instantly select the LTS kernel at boot.

linux-firmware & sof-firmware: Installs the firmware code files for internal components. sof-firmware (Sound Open Firmware) is specifically required to drive modern AMD onboard internal audio controllers.

btrfs-progs: Provides the operational commands inside the system to manage snapshots and drive containers.

2. Generate the File System Table
Bash
genfstab -U /mnt >> /mnt/etc/fstab
Why: The -U flag commands the script to map drive points via their Universally Unique Identifier (UUID) values rather than physical naming links (like /dev/nvme0n1p2). If you insert secondary drives or memory cards later, their structural mounting points will not break due to shifting device names.

3. Enter the Chroot Jail Environment
Shift your execution context directly inside your newly deployed operating system:

Bash
arch-chroot /mnt
4. Localization and System Time Management
Bash
ln -sf /usr/share/zoneinfo/America/Mexico_City /etc/localtime
hwclock --systohc

echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "es_MX.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen

echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "thinkpad-dev" > /etc/hostname
Why: hwclock --systohc synchronizes your system hardware motherboard clock to your active timezone, preventing timestamp drifts during dual-booting setups or Git version logs.

5. Create the Developer Profile (carael)
Bash
# Define administrative root passwords
passwd

# Establish your primary developer workspace identity
useradd -m -G wheel -s /bin/bash carael
passwd carael

# Authorize administrative privileges
echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/wheel
Why: The user account is assigned to the wheel security group, which grants access to sudo command delegation. Adding an isolated rule inside /etc/sudoers.d/ prevents editing errors from corrupting the core system configuration files.

6. Install and Configure the GRUB Bootloader
Bash
pacman -S grub efibootmgr
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg
Why: efibootmgr allows the system to communicate directly with the motherboard's UEFI registers, registering GRUB as a secure native primary boot choice.

Phase 5: Isolated Native Network Engine Architecture
To build a clean, minimalist developer environment, we completely exclude heavy network management software like NetworkManager. Instead, we leverage the ultra-fast, native system network tools already built directly into the core operating system framework (systemd-networkd).

1. Install Wireless Management Tooling
Bash
pacman -S iwd
Why: iwd (Internet Wireless Daemon) is a pure, ultra-lightweight wireless engine built specifically for the Linux kernel by Intel. It uses significantly fewer system resources than standard tools and executes connections much faster.

2. Fully Disable and Mask NetworkManager Sockets
Bash
systemctl disable NetworkManager NetworkManager-dispatcher NetworkManager-wait-online
systemctl mask NetworkManager
Why: Masking links the NetworkManager configuration service directly to /dev/null. This ensures that if you install a package later that lists NetworkManager as a dependency, it can never be started in the background, preventing resource conflicts with your working network layout.

3. Write Priority Network Configuration Engines
Create clear instructions inside /etc/systemd/network/ to manage automatic routing prioritization. systemd-networkd reads these configuration files in alphanumeric order (lowest number first).

File 1: 10-ethernet.network (Primary Wired Pipeline)
Bash
nano /etc/systemd/network/10-ethernet.network
Add these exact lines:

Ini, TOML
[Match]
Name=enp*

[Network]
DHCP=yes
Why: Matches any interface starting with enp (your physical Ethernet port). It handles standard DHCP address assignments instantly when an Ethernet cable is plugged in. Because it starts with 10-, it takes absolute priority over Wi-Fi, routing traffic over the faster wired line automatically.

File 2: 20-wlan.network (Secondary Wireless Pipeline)
Bash
nano /etc/systemd/network/20-wlan.network
Add these exact lines:

Ini, TOML
[Match]
Name=wlan*

[Network]
DHCP=yes
Why: Catches your internal wireless interface (wlan0). If the Ethernet link is absent (no-carrier), the system moves down the priority list to this profile, requesting an automatic dynamic IP from your wireless access points.

4. Connect the Automated DNS Subsystem
Bash
ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
Why: Connects your legacy global system DNS resolver config file directly to the dynamic systemd-resolved runtime cache. This ensures your domain name translations automatically refresh whenever you switch networks.

5. Enable System Network Services on Boot
Bash
systemctl enable systemd-networkd.socket
systemctl enable systemd-networkd
systemctl enable systemd-resolved
systemctl enable iwd
Phase 6: Automated Snapper Backup Integration
To isolate system tracking data into your flat @snapshots subvolume boundary, use this configuration override pattern.

1. Install Snapper
Bash
pacman -S snapper
2. Execute the Snapper Alignment Override Loop
Snapper's default create-config command assumes it needs to build a new subvolume from scratch. Because we already created our own optimized @snapshots subvolume and mounted it to /.snapshots, running the tool standard will cause an immediate directory collision error. We override this behavior with this exact pattern:

Bash
# 1. Temporarily unmount your custom physical subvolume location
umount /.snapshots

# 2. Trigger Snapper's default configuration template file initialization
snapper -c root create-config /

# 3. Wipe the local plain directory template Snapper generated in its place
btrfs subvolume delete /.snapshots || rm -rf /.snapshots

# 4. Re-create a clean, empty mount directory point folder
mkdir -p /.snapshots

# 5. Tell systemd to reload your fstab parameters and remount your isolated subvolume
systemctl daemon-reload
mount -a
Why This Step Is Critical: This safely bridges Snapper’s administrative templates with your isolated, flat hardware subvolume @snapshots. System restores can now be performed instantly without destroying snapshot histories.

3. Elevate Local User Administration Permissions
Bash
nano /etc/snapper/configs/root
Locate the user line and inject your primary account name inside the parameters:

Plaintext
ALLOW_USERS="carael"
Why: This lets user carael run diagnostic snapshot commands and view history logs without needing to prefix every command with sudo.

4. Configure Lean Workstation Retention Limits
Within the same configuration file (/etc/snapper/configs/root), scroll to the TIMELINE_LIMIT blocks and adjust the retention rules to keep your filesystem light:

Plaintext
TIMELINE_LIMIT_HOURLY="3"
TIMELINE_LIMIT_DAILY="5"
TIMELINE_LIMIT_WEEKLY="2"
TIMELINE_LIMIT_MONTHLY="0"
TIMELINE_LIMIT_YEARLY="0"
Why This Configuration? > * HOURLY="3": Retains backups for the last 3 hours of active development, providing a quick fallback if a localized file script fails.

DAILY="5" & WEEKLY="2": Retains historical save states for the current week and previous fortnight.

MONTHLY/YEARLY="0": Avoids storing months of old operational data. Long-term project tracking belongs in remote Git repositories, not system backup directories.

5. Activate Automated Timers
Bash
systemctl enable --now snapper-timeline.timer
systemctl enable --now snapper-cleanup.timer
Why: snapper-timeline.timer fires an automated system snapshot at the start of every hour. snapper-cleanup.timer automatically runs in the background to prune old snapshots based on the timeline rules we just defined.

6. Verify and Trigger Your Initial Baseline Backup
Bash
# Run your first manual save point
snapper -c root create --description "Post-Installation Baseline Work"

# Verify snapshot logs
snapper -c root list
Phase 7: Finalizing the Environment
Your workstation layout is completely configured, protected by automated snapshots, and ready for use. Exit the environment and reboot natively into your system:

Bash
exit
umount -R /mnt
reboot
💡 Working with Your System Going Forward
Connecting to Wi-Fi Natively: Use the interactive wireless daemon tool in your user terminal:

Bash
iwctl
# Inside iwctl prompt:
station wlan0 get-networks
station wlan0 connect YOUR_SSID
Verifying Network Integrity:

Bash
networkctl list
Listing Active System Snapshots:

Bash
snapper -c root list
