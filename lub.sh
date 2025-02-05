#!/bin/bash

# Live Ubuntu Backup V2.2, Nov 4th,2009
# Copyright (C) 2009 billbear <billbear@gmail.com>

# This program is free software; you can redistribute it and/or modify it 
# under the terms of the GNU General Public License as published by 
# the Free Software Foundation; either version 2 of the License, 
# or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but 
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY 
# or FITNESS FOR A PARTICULAR PURPOSE. 
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with this program; 
# if not, see <http://www.gnu.org/licenses>.

mypath=$0

VOL_ID(){
	[ "$2" = "" ] && return
	local voluuid=""
	local voltype=""
	for i in `blkid $2`; do
	[ "${i#UUID=\"}" != "$i" ] && voluuid="${i#UUID=\"}" && voluuid="${voluuid%\"}"
	[ "${i#TYPE=\"}" != "$i" ] && voltype="${i#TYPE=\"}" && voltype="${voltype%\"}"
	done
	[ "$1" = "--uuid" ] && echo $voluuid
	[ "$1" = "--type" ] && echo $voltype
}

new_dir(){
	local newdir="$*"
	i=0
	while [ -e $newdir ]; do
	i=`expr $i + 1`
	newdir="$*-$i"
	done
	echo $newdir
}

echoredcn(){
	[ $lang = "cn" ] && echo -e "\033[41m$*\033[0m"
	return 0
}

echoreden(){
	[ $lang = "en" ] && echo -e "\033[31m$*\033[0m"
	return 0
}

echocn(){
	[ $lang = "cn" ] && echo $*
	return 0
}

echoen(){
	[ $lang = "en" ] && echo $*
	return 0
}

packagecheck_b(){
	dpkg -l | grep ^ii | sed 's/[ ][ ]*/ /g' | cut -d " " -f 2 | grep ^squashfs-tools$ > /dev/null || { echoreden "squashfs-tools is required to run this program. You can install it by typing:\nsudo apt install squashfs-tools\nYou may need a working internet connection to do that."; echoredcn "要运行此程序必须先安装 squashfs-tools。你可以用如下命令安装:\nsudo apt install squashfs-tools\n这需要连上互联网。"; exit 1; }
	dpkg -l | grep ^ii | sed 's/[ ][ ]*/ /g' | cut -d " " -f 2 | grep ^casper$ > /dev/null || { echoreden "casper is required to run this program. You can install it by typing:\nsudo apt install casper\nYou may need a working internet connection to do that."; echoredcn "要运行此程序必须先安装 casper。你可以用如下命令安装:\nsudo apt install casper\n这需要连上互联网。"; exit 1; }
	dpkg -l | grep ^ii | sed 's/[ ][ ]*/ /g' | cut -d " " -f 2 | grep ^parted$ > /dev/null || { echoreden "parted is required to run this program. You can install it by typing:\nsudo apt install parted\nYou may need a working internet connection to do that."; echoredcn "要运行此程序必须先安装 parted。你可以用如下命令安装:\nsudo apt install parted\n这需要连上互联网。"; exit 1; }
}

packagecheck_r(){
	dpkg -l | grep ^ii | sed 's/[ ][ ]*/ /g' | cut -d " " -f 2 | grep ^parted$ > /dev/null || { echoreden "parted is required to run this program. You can install it by typing:\nsudo apt install parted\nYou may need a working internet connection to do that."; echoredcn "要运行此程序必须先安装 parted。你可以用如下命令安装:\nsudo apt install parted\n这需要连上互联网。"; exit 1; }
}

rebuildtree(){ # Remounting the linux directories effectively excludes removable media, manually mounted devices, windows partitions, virtual files under /proc, /sys, /dev, the /host contents of a wubi install, etc. If your partition scheme is more complicated than listed below, you must add lines to rebuildtree() and destroytree(), otherwise the backup will be partial.
	mkdir /$1

#	mkdir /$1/boot/
#	mkdir /$1/home/
#	mkdir /$1/tmp/
#	mkdir /$1/usr/
#	mkdir /$1/var/
#	mkdir /$1/srv/
#	mkdir /$1/opt/
#	mkdir /$1/usr/local/

	mount --bind / /$1/

#	mount --bind /boot /$1/boot/
#	mount --bind /home /$1/home/
#	mount --bind /tmp /$1/tmp/
#	mount --bind /usr /$1/usr/
#	mount --bind /var /$1/var/
#	mount --bind /srv /$1/srv/
#	mount --bind /opt /$1/opt/
#	mount --bind /usr/local /$1/usr/local/
}

destroytree(){
#	umount /$1/usr/local
#	umount /$1/opt
#	umount /$1/srv
#	umount /$1/var
#	umount /$1/usr
#	umount /$1/tmp
#	umount /$1/home
#	umount /$1/boot
	umount /$1
	rmdir /$1
}

target_cmd(){
	mount --bind /proc $1/proc
	mount --bind /dev $1/dev
	mount --bind /sys $1/sys
	chroot $*
	umount $1/sys
	umount $1/dev
	umount $1/proc
}

dequotepath(){ # If drag n drop from nautilus into terminal, the additional single quotes should be removed first.
	local tmpath="$*"
	[ "${tmpath#\'}" != "$tmpath" ] && [ "${tmpath%\'}" != "$tmpath" ] && { tmpath="${tmpath#\'}"; tmpath="${tmpath%\'}"; }
	echo "$tmpath"
}

checkbackupdir(){
	[ "${1#/}" = "$1" ] && { echoreden "You must specify the absolute path"; echoredcn "请使用绝对路径"; exit 1; }
	[ -d "$*" ] || { echoreden "$* does not exist, or is not a directory"; echoredcn "$* 不存在, 或并非目录"; exit 1; }
	[ `ls -A "$*" | wc -l` = 0 ] || { echoreden "$* is not empty"; echoredcn "$* 不是空目录"; exit 1; }
}

probe_partitions(){
	for i in /dev/[hs]d[a-z][0-9]*; do
	blkid $i > /dev/null 2>&1 || continue
	parted -s $i print > /dev/null 2>&1 || continue
	part[${#part[*]}]=$i
	oldfstype[${#oldfstype[*]}]=`$VOL_ID --type $i`
	size=`parted -s $i print | grep $i`
	size=${size#*:}
	size=${size#*：}	#全角冒号，台湾 parted 输出用这个 :(
	partinfo[${#partinfo[*]}]="$i `$VOL_ID --type $i` $size"
	done
}

choose_partition(){
	select opt in "${partinfo[@]}"; do
	[ "$opt" = "" ] && continue
	arrno=`expr $REPLY - 1`
	[ $REPLY -gt ${#part[*]} ] && break
	echoreden "You selected ${part[$arrno]}, it currently contains these files/directories:"
	echoredcn "你选择的是 ${part[$arrno]}, 里面现有这些文件/目录:"
	tmpdir=`new_dir /tmp/mnt`
	[ "${oldfstype[$arrno]}" = "swap" ] || { mkdir $tmpdir; mount ${part[$arrno]} $tmpdir; ls -A $tmpdir; umount $tmpdir; rmdir $tmpdir; }
	echoreden "confirm?(y/n)"
	echoredcn "确定?(y/n)"
	read yn
	[ "$yn" != "y" ] && echoreden "Select again" && echoredcn "重新选择" && continue
	partinfo[$arrno]=""
	break
	done

	eval $1=$arrno
	[ $REPLY -gt ${#part[*]} ] && return
	[ $1 = swappart ] && echoreden "${part[$arrno]} will be formatted as swap." && echoredcn "${part[$arrno]} 将被格式化为 swap." && return

	if [ "${oldfstype[$arrno]}" = "ext2" -o "${oldfstype[$arrno]}" = "ext3" -o "${oldfstype[$arrno]}" = "ext4" -o "${oldfstype[$arrno]}" = "reiserfs" -o "${oldfstype[$arrno]}" = "jfs" -o "${oldfstype[$arrno]}" = "xfs" ]; then
	echoreden "Do you want to format this partition?(y/n)"
	echoredcn "是否格式化此分区?(y/n)"
	read yn
	[ "$yn" != "y" ] && newfstype[$arrno]="keep" && return
	fi
	echoreden "Format ${part[$arrno]} as:"
	echoredcn "格式化 ${part[$arrno]} 为:"

	select opt in ext2 ext3 ext4 reiserfs jfs xfs; do
	[ "$opt" = "" ] && continue
	ls /sbin/mkfs.$opt > /dev/null 2>&1 && break
	echoreden "mkfs.$opt is not installed."
	echoredcn "mkfs.$opt 尚未安装。"
	[ "$opt" = "reiserfs" ] && echoreden "You can install it by typing\nsudo apt-get install reiserfsprogs" && echoredcn "你可以通过如下命令安装\nsudo apt-get install reiserfsprogs"
	[ "$opt" = "jfs" ] && echoreden "You can install it by typing\nsudo apt-get install jfsutils" && echoredcn "你可以通过如下命令安装\nsudo apt-get install jfsutils"
	[ "$opt" = "xfs" ] && echoreden "You can install it by typing\nsudo apt-get install xfsprogs" && echoredcn "你可以通过如下命令安装\nsudo apt-get install xfsprogs"
	echoreden "Please re-select file system type."
	echoredcn "请重新选择文件系统。"
	done

	newfstype[$arrno]=$opt
}

setup_target_partitions(){
	rootpart=1000
	swappart=1000
	homepart=1000
	bootpart=1000
	tmppart=1000
	usrpart=1000
	varpart=1000
	srvpart=1000
	optpart=1000
	usrlocalpart=1000

	echoreden "Which partition do you want to use as / ?"
	echoredcn "将哪个分区作为 / ?"
	choose_partition rootpart

	[ $lang = "cn" ] && partinfo[${#partinfo[*]}]="无" || partinfo[${#partinfo[*]}]="None"
	[ $lang = "cn" ] && partinfo[${#partinfo[*]}]="无，并结束分区设定。" || partinfo[${#partinfo[*]}]="None and finish setting up partitions"

	echoreden "Which partition do you want to use as swap ?"
	echoredcn "将哪个分区作为 swap ?"
	choose_partition swappart
	[ $arrno -gt ${#part[*]} ] && return

	for i in home boot tmp usr var srv opt; do
	echoreden "Which partition do you want to use as /$i ?"
	echoredcn "将哪个分区作为 /$i ?"
	eval choose_partition ${i}part
	[ $arrno -gt ${#part[*]} ] && return
	done

	echoreden "Which partition do you want to use as /usr/local ?"
	echoredcn "将哪个分区作为 /usr/local ?"
	choose_partition usrlocalpart
}

umount_target_partitions(){
	for i in usrlocalpart swappart homepart bootpart tmppart usrpart varpart srvpart optpart rootpart; do
	eval thispart=\$$i
	[ "${part[$thispart]}" = "" ] && continue
	[ "${newfstype[$thispart]}" = "keep" ] && continue
		while mount | grep "^${part[$thispart]} " > /dev/null; do
		umount ${part[$thispart]} || { echoreden "Failed to umount ${part[$thispart]}"; echoredcn "无法卸载 ${part[$thispart]}"; exit 1; }
		done
	[ $i = swappart ] && continue
	swapon -s | grep "^${part[$thispart]} " > /dev/null && echoreden "swapoff ${part[$thispart]} and try again." && echoredcn "请先 swapoff ${part[$thispart]}" && exit 1
	done
}

format_target_partitions(){
	for i in rootpart homepart bootpart tmppart usrpart varpart srvpart optpart usrlocalpart; do
	eval thispart=\$$i
	[ "${part[$thispart]}" = "" ] && continue
	[ "${newfstype[$thispart]}" = "keep" ] && continue
	echoreden "Formatting ${part[$thispart]}"
	echoredcn "正在格式化 ${part[$thispart]}"
	[ "${newfstype[$thispart]}" = "xfs" ] && formatoptions=fq || formatoptions=q
	mkfs.${newfstype[$thispart]} -$formatoptions ${part[$thispart]} > /dev/null || { echoreden "Failed to format ${part[$thispart]}"; echoredcn "无法格式化 ${part[$thispart]}"; exit 1; }
	disk=`expr substr ${part[$thispart]} 1 8`
	num=${part[$thispart]#$disk}
	sfdisk --part-type -f $disk $num linux
	done

	[ "${part[$swappart]}" = "" ] && return
	[ "${oldfstype[$swappart]}" = "swap" ] && return
	echoreden "Formatting ${part[$swappart]}"
	echoredcn "正在格式化 ${part[$swappart]}"
	mkfs.ext2 -q ${part[$swappart]} || { echoreden "Failed to format ${part[$swappart]}"; echoredcn "无法格式化 ${part[$swappart]}"; exit 1; }
	mkswap ${part[$swappart]} || { echoreden "Failed to format ${part[$swappart]}"; echoredcn "无法格式化 ${part[$swappart]}"; exit 1; }
	disk=`expr substr ${part[$swappart]} 1 8`
	num=${part[$swappart]#$disk}
	sfdisk --part-type -f $disk $num swap
}

chkuuids(){
	uuids=""
	for i in /dev/[hs]d[a-z][0-9]*; do
	uuids="$uuids\n`$VOL_ID --uuid $i 2> /dev/null`"
	done
	[ "`echo -e $uuids | sort | uniq -d`" = "" ] && return
	echoreden "duplicate UUIDs detected! The program will now terminate."
	echoredcn "检测到某些分区有重复的 UUID! 程序将终止。"
	exit 1
}

mount_target_partitions(){
	tgt=`new_dir /tmp/target`
	mkdir $tgt
	mount ${part[$rootpart]} $tgt
	[ "${part[$homepart]}" != "" ] && mkdir -p $tgt/home && mount ${part[$homepart]} $tgt/home
	[ "${part[$bootpart]}" != "" ] && mkdir -p $tgt/boot && mount ${part[$bootpart]} $tgt/boot
	[ "${part[$tmppart]}" != "" ] && mkdir -p $tgt/tmp && mount ${part[$tmppart]} $tgt/tmp
	[ "${part[$usrpart]}" != "" ] && mkdir -p $tgt/usr && mount ${part[$usrpart]} $tgt/usr
	[ "${part[$varpart]}" != "" ] && mkdir -p $tgt/var && mount ${part[$varpart]} $tgt/var
	[ "${part[$srvpart]}" != "" ] && mkdir -p $tgt/srv && mount ${part[$srvpart]} $tgt/srv
	[ "${part[$optpart]}" != "" ] && mkdir -p $tgt/opt && mount ${part[$optpart]} $tgt/opt
	[ "${part[$usrlocalpart]}" != "" ] && mkdir -p $tgt/usr/local && mount ${part[$usrlocalpart]} $tgt/usr/local
}

gettargetmount(){ # Generate a list of mounted partitions and mount points of the restore target.
	for i in `mount | grep " $* "`; do
	[ "${i#/dev/}" != "$i" ] && echo $i
	[ "$i" = "$*"  ] && echo "$i/"
	done

	for i in `mount | grep " $*/"`; do
	[ "${i#/}" != "$i" ] && echo $i
	done
}

getdefaultgrubdev(){ # Find the root or boot partition.
	local bootdev=""
	local rootdev=""
	for i in $*; do
	[ "$i" = "$tgt/" ] && rootdev="$j" || j=$i
	[ "$i" = "$tgt/boot" ] && bootdev="$k" || k=$i
	done
	[ "$bootdev" = "" ] && echo $rootdev && return
	echo $bootdev && return 67
}

listgrubdev(){
	for i in /dev/[hs]d[a-z]; do
	echo $i,MBR
	done

	for i in /dev/[hs]d[a-z][0-9]*; do
	blkid $i > /dev/null 2>&1 || continue
	[ "`$VOL_ID --type $i`" = "ntfs" ] && continue
	parted -s $i print > /dev/null 2>&1 || continue
	echo $i,`$VOL_ID --type $i`
	done

	echoen none,not_recommended
	echocn 不安装（不推荐）
}

getmountoptions(){ # According to the default behavior of ubuntu installer. You can alter these or add options for other fs types.
	case "$*" in
	"/ ext4" ) echo relatime,errors=remount-ro;;
	"/ ext3" ) echo relatime,errors=remount-ro;;
	"/ ext2" ) echo relatime,errors=remount-ro;;
	"/ reiserfs" ) [ "$hasboot" = "yes" ] && echo relatime || echo notail,relatime;;
	"/ jfs" ) echo relatime,errors=remount-ro;;

	"/boot reiserfs" ) echo notail,relatime;;

	*"ntfs" ) echo defaults,umask=007,gid=46;;
	*"vfat" ) echo utf8,umask=007,gid=46;;
	*) echo relatime;;
	esac
}

generate_fstab(){
	local targetfstab="$*/etc/fstab"

	echo "# /etc/fstab: static file system information." > "$targetfstab"
	echo "#" >> "$targetfstab"
	echo "# <file system> <mount point>   <type>  <options>       <dump>  <pass>" >> "$targetfstab"

	for i in $tgtmnt; do
	[ "${i#/dev/}" != "$i" ] && { echo "# $i" >> "$targetfstab"; j=$i; continue; }
	uuid="`$VOL_ID --uuid $j`"
	[ "$uuid" = "" ] && partition=$j || partition="UUID=$uuid"
	mntpnt=${i#$tgt}
	fs=`$VOL_ID --type $j`
	fsckorder=`echo "${i#$tgt/} s" | wc -w`
	echo "$partition $mntpnt $fs `getmountoptions "$mntpnt $fs"` 0 $fsckorder" >> "$targetfstab"
	done

	for i in /dev/[hs]d[a-z][0-9]*; do
	[ "`$VOL_ID --type $i 2> /dev/null`" = swap ] || continue
	echo "# $i" >> "$targetfstab"
	swapuuid="`$VOL_ID --uuid $i`"
	[ "$swapuuid" = "" ] && partition=$i || partition="UUID=$swapuuid"
	echo "$partition none swap sw 0 0" >> "$targetfstab"
	haswap="yes"
	[ -f $tgt/etc/initramfs-tools/conf.d/resume ] || { echo "RESUME=$partition" > $tgt/etc/initramfs-tools/conf.d/resume; continue; }
	lastresume="`cat $tgt/etc/initramfs-tools/conf.d/resume`"
	lastresume="${lastresume#RESUME=}"
	[ "${lastresume#UUID=}" != "$lastresume" ] && lastresume="`parted /dev/disk/by-uuid/${lastresume#UUID=} unit B print | grep /dev/`"
	[ "${lastresume#/dev/}" != "$lastresume" ] && lastresume="`parted $lastresume unit B print | grep /dev/`"
	lastresume=${lastresume#*:}
	lastresume=${lastresume#*：}	#有可能是全角冒号
	lastresume=${lastresume%B}
	thisresume="`parted $i unit B print | grep $i`"
	thisresume=${thisresume#*:}
	thisresume=${thisresume#*：}	#有可能是全角冒号
	thisresume=${thisresume%B}
	[ "$thisresume" -gt "$lastresume" ] && echo "RESUME=$partition" > $tgt/etc/initramfs-tools/conf.d/resume
	done

#	echo "/dev/scd0 /media/cdrom0 udf,iso9660 user,noauto,exec,utf8 0 0" >> "$targetfstab"
}

makelostandfound(){ # If lost+found is removed from an ext? FS, create it with the command mklost+found. Don't just mkdir lost+found
	for i in $tgtmnt; do
	[ "${i#/dev/}" != "$i" ] && j=$i
	[ "${i#$tgt}" != "$i" ] &&  $VOL_ID --type $j | grep ext > /dev/null && cd $i && mklost+found 2> /dev/null
	done
}

makeswapfile(){
	echoreden "You do not have a swap partition. Would you like a swap file? Default is yes.(y/n)"
	echoredcn "你没有 swap 分区。是否做一个 swap 文件? 默认的回答为是。(y/n)"
	read yn
	[ "$yn" = "n" ] && return
	echoreden "The size of the swap file in megabytes, defaults to 512"
	echoredcn "做一个多少兆的 swap 文件? 默认值为 512"
	read swapsize
	swapsize=`expr $swapsize + 0 2> /dev/null`
	[ "$swapsize" = "" ] && swapsize=512
	[ "$swapsize" = "0" ] && swapsize=512
	local sf=`new_dir $*/swap.img`
	echoreden "Generating swap file..."
	echoredcn "正在创建 swap 文件..."
	dd if=/dev/zero of=$sf bs=1M count=$swapsize
	mkswap $sf
	echo "${sf#$*}  none  swap  sw  0 0" >> "$*/etc/fstab"
}

sqshboot_grubcfg(){ # Generate a windows-notepad-compatible menu.lst in the backup directory with instructions to boot backup.squashfs directly.
	[ $lang = "cn" ] && echo -e "# 这个 grub.cfg 用于启动live CD


# 如何在 linux 机器上直接启动你的 backup$today.squashfs:
# 使用rufus制作grub2.0(x)U盘启动盘, 
# 	1. 文件系统: FAT32
# 	2. 在根目录建立一个 \"casper\" 文件夹
#	3. 拷贝 backup$today.squashfs, initrd.img-`uname -r`, vmlinuz-`uname -r` 到 \"casper\" 
# 	4. 拷贝 boot 文件夹到根目录\r
# 如果使用linux平台制作grub启动盘，则需要更改root

# Instructions to boot your backup$today.squashfs directly on a linux PC:
# use rufus make grub2.0(x) boot u disk
# 	1. filesystem: FAT32
#	2. create \"casper\" file folder on root
#	3. copy backup$today.squashfs, initrd.img-`uname -r`, vmlinuz-`uname -r` to \"casper\" 
#	4. copy boot folder to root
# you may need to change the root if you use linux platform to make a boot disk
"

echo -e "

set timeout=30
loadfont unicode
set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry \"Live Ubuntu Backup $today\" {
	set gfxpayload=keep
	set root=(hd0,msdos1)
	linux	/casper/vmlinuz-`uname -r` boot=casper
	initrd	/casper/initrd.img-`uname -r`
}
menuentry 'Test memory' {
	linux16 /boot/memtest86+.bin
}
"
}

windowsentry(){
	for i in /dev/[hs]d[a-z][0-9]*; do
	volid="`$VOL_ID --type $i 2> /dev/null`"
	[ "$volid" != ntfs -a "$volid" != vfat ] && continue
	tmpdir=`new_dir /tmp/mnt`
	mkdir $tmpdir
	mount $i $tmpdir || { rmdir $tmpdir; continue; }
	disk=`expr substr $i 1 8`
	num=${i#$disk}
	num=`expr $num - 1`
	[ -f $tmpdir/bootmgr -o -f $tmpdir/ntldr ] && { echo >> $tgt/boot/grub/menu.lst; echo "# This entry may not be correct when you have multiple hard disks" >> $tgt/boot/grub/menu.lst; echo "title windows" >> $tgt/boot/grub/menu.lst; echo "rootnoverify (hd0,$num)" >> $tgt/boot/grub/menu.lst; echo "chainloader +1" >> $tgt/boot/grub/menu.lst; }
	umount $i
	rmdir $tmpdir
	done
}

cleartgtmnt(){
	[ "${part[$usrlocalpart]}" != "" ] && umount ${part[$usrlocalpart]}
	[ "${part[$homepart]}" != "" ] && umount ${part[$homepart]}
	[ "${part[$bootpart]}" != "" ] && umount ${part[$bootpart]}
	[ "${part[$tmppart]}" != "" ] && umount ${part[$tmppart]}
	[ "${part[$usrpart]}" != "" ] && umount ${part[$usrpart]}
	[ "${part[$varpart]}" != "" ] && umount ${part[$varpart]}
	[ "${part[$srvpart]}" != "" ] && umount ${part[$srvpart]}
	[ "${part[$optpart]}" != "" ] && umount ${part[$optpart]}
	umount ${part[$rootpart]} || { echoreden "Please umount $tgt yourself"; echoredcn "请自行卸载 $tgt"; }
}


dobackup1(){
	bindingdir=`new_dir /tmp/bind`
	backupdir=`new_dir ~/backup-$today`
	bindingdir="${bindingdir#/}"
	backupdir="${backupdir#/}"
#	packagecheck_b
#	packagecheck_r
	echoreden "You are about to backup your system. It is recommended that you quit all open applications now. Continue?(y/n)"
	echoredcn "将要备份系统。建议退出其他程序。继续?(y/n)"
	read yn
	[ "$yn" != "y" ] && exit 1
	echoreden "Specify an empty directory(absolute path) to save the backup. You can drag directory from Nautilus File Manager and drop it here. Feel free to use external media.
If you don't specify, the backup will be saved to /$backupdir"
	echoredcn "指定一个空目录 (绝对路径) 来存放备份。\n可以从 Nautilus 文件管理器拖放目录至此。\n可以使用移动硬盘。\n如果不指定, 将会存放到 /$backupdir"
	read userdefined_backupdir
	[ "$userdefined_backupdir" != "" ] && { userdefined_backupdir="`dequotepath "$userdefined_backupdir"`"; checkbackupdir "$userdefined_backupdir"; backupdir="${userdefined_backupdir#/}"; }

	exclude=`new_dir /tmp/exclude`
	echo $backupdir > $exclude
	echo $bindingdir >> $exclude
	echo boot/grub >> $exclude
	echo etc/fstab >> $exclude
	echo etc/mtab >> $exclude
	echo etc/blkid.tab >> $exclude
	echo etc/udev/rules.d/70-persistent-net.rules >> $exclude
	echo lost+found >> $exclude
	echo boot/lost+found >> $exclude
	echo home/lost+found >> $exclude
	echo tmp/lost+found >> $exclude
	echo usr/lost+found >> $exclude
	echo var/lost+found >> $exclude
	echo srv/lost+found >> $exclude
	echo opt/lost+found >> $exclude
	echo usr/local/lost+found >> $exclude

	for i in `swapon -s | grep file | cut -d " " -f 1`; do
	echo "${i#/}" >> $exclude
	done

	for i in `ls /tmp -A`; do
	echo "tmp/$i" >> $exclude
	done

	echoreden "Do you want to exclude all user files in /home? (y/n)"
	echoredcn "是否排除 /home 里所有的用户文件? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /home/*; do
	[ -f "$i" ] && echo "${i#/}" >> $exclude
	[ -d "$i" ] || continue
		for j in "$i"/*; do
		[ -e "$j" ] && echo "${j#/}" >> $exclude
		done
	done
	fi

	echoreden "Do you want to exclude all user configurations (hidden files) in /home as well? (y/n)"
	echoredcn "是否也排除 /home 里所有的用户配置文件(隐藏文件)? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /home/*; do
	[ -d "$i" ] || continue
		for j in "$i"/.*; do
		[ "$j" = "$i/." ] && continue
		[ "$j" = "$i/.." ] && continue
		echo "${j#/}" >> $exclude
		done
	done
	fi

	echoreden "Do you want to exclude the local repository of retrieved package files in /var/cache/apt/archives/ ? (y/n)"
	echoredcn "是否排除已下载软件包在 /var/cache/apt/archives/ 里的本地缓存 ? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /var/cache/apt/archives/*.deb; do
	[ -e "$i" ] && echo "${i#/}" >> $exclude
	done
	for i in /var/cache/apt/archives/partial/*; do
	[ -e "$i" ] && echo "${i#/}" >> $exclude
	done
	fi

	echoreden "(For advanced users only) Specify other files/folders you want to exclude from the backup, one file/folder per line. You can drag and drop from Nautilus. End with an empty line.\nNote that the program has automatically excluded all removable media, windows partitions, manually mounted devices, files under /proc, /sys, /tmp, the /host contents of a wubi install, etc. So in most cases you can just hit enter now.\nIf you exclude important system files/folders, the backup will fail to restore."
	echoredcn "(高级用户功能)指定其他需要排除的文件/目录, 一行写一个。以空行结束。\n可以从 Nautilus 文件管理器拖放至此。\n注意程序已经自动排除所有移动设备, windows 分区, 手动挂载的所有设备, /proc, /sys, /tmp 下的文件, wubi 的 /host 内容, 等等。\n所以在绝大多数情况下你只需要直接回车就可以了。\n如果你排除了重要的系统文件/目录, 不要指望你的备份能够工作。"
	read ex
	while [ "$ex" != "" ]; do
	ex=`dequotepath "$ex"`
	[ "${ex#/}" = "$ex" ] && { echoen "You must specify the absolute path"; echocn "请使用绝对路径"; read ex; continue; }
	[ -e "$ex" ] || { echoen "$ex does not exist"; echocn "$ex 并不存在"; read ex; continue; }
	ex="${ex#/}"
	echo $ex >> $exclude
	read ex
	done

	rebuildtree $bindingdir

	for i in /$bindingdir/media/*; do
	ls -ld "$i" | grep "^drwx------ " > /dev/null || continue
	[ `ls -A "$i" | wc -l` = 0 ] || continue
	echo "${i#/$bindingdir/}" >> $exclude
	done

	echoreden "Start to backup?(y/n)"
	echoredcn "开始备份?(y/n)"
	read yn
	[ "$yn" != "y" ] && { destroytree $bindingdir; rm $exclude; exit 1; }
	stime=`date`
	mkdir -p "/$backupdir"
	mksquashfs /$bindingdir "/$backupdir/backup$today.squashfs" -ef $exclude
	destroytree $bindingdir
	rm $exclude
#	cp /boot/initrd.img-`uname -r` "/$backupdir"
#	cp /boot/vmlinuz-`uname -r` "/$backupdir"
#	sqshboot_grubcfg > "/$backupdir/grub.cfg"
	thisuser=`basename ~`
	chown -R $thisuser:$thisuser "/$backupdir" 2> /dev/null
	echoreden "Your backup is ready in /$backupdir. :)"
	echoreden " started at: $stime\nfinished at: `date`"
	echoredcn "已备份至 /$backupdir。:)"
	echoredcn "开始于: $stime\n结束于: `date`"
	tput bel
}

dobackup(){
	bindingdir=`new_dir /tmp/bind`
	backupdir=`new_dir ~/backup-$today`
	bindingdir="${bindingdir#/}"
	backupdir="${backupdir#/}"
	packagecheck_b
	packagecheck_r
	echoreden "You are about to backup your system. It is recommended that you quit all open applications now. Continue?(y/n)"
	echoredcn "将要备份系统。建议退出其他程序。继续?(y/n)"
	read yn
	[ "$yn" != "y" ] && exit 1
	echoreden "Specify an empty directory(absolute path) to save the backup. You can drag directory from Nautilus File Manager and drop it here. Feel free to use external media.
If you don't specify, the backup will be saved to /$backupdir"
	echoredcn "指定一个空目录 (绝对路径) 来存放备份。\n可以从 Nautilus 文件管理器拖放目录至此。\n可以使用移动硬盘。\n如果不指定, 将会存放到 /$backupdir"
	read userdefined_backupdir
	[ "$userdefined_backupdir" != "" ] && { userdefined_backupdir="`dequotepath "$userdefined_backupdir"`"; checkbackupdir "$userdefined_backupdir"; backupdir="${userdefined_backupdir#/}"; }

	exclude=`new_dir /tmp/exclude`
	echo $backupdir > $exclude
	echo $bindingdir >> $exclude
	echo boot/grub >> $exclude
	echo etc/fstab >> $exclude
	echo etc/mtab >> $exclude
	echo etc/blkid.tab >> $exclude
	echo etc/udev/rules.d/70-persistent-net.rules >> $exclude
	echo lost+found >> $exclude
	echo boot/lost+found >> $exclude
	echo home/lost+found >> $exclude
	echo tmp/lost+found >> $exclude
	echo usr/lost+found >> $exclude
	echo var/lost+found >> $exclude
	echo srv/lost+found >> $exclude
	echo opt/lost+found >> $exclude
	echo usr/local/lost+found >> $exclude

	for i in `swapon -s | grep file | cut -d " " -f 1`; do
	echo "${i#/}" >> $exclude
	done

	for i in `ls /tmp -A`; do
	echo "tmp/$i" >> $exclude
	done

	echoreden "Do you want to exclude all user files in /home? (y/n)"
	echoredcn "是否排除 /home 里所有的用户文件? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /home/*; do
	[ -f "$i" ] && echo "${i#/}" >> $exclude
	[ -d "$i" ] || continue
		for j in "$i"/*; do
		[ -e "$j" ] && echo "${j#/}" >> $exclude
		done
	done
	fi

	echoreden "Do you want to exclude all user configurations (hidden files) in /home as well? (y/n)"
	echoredcn "是否也排除 /home 里所有的用户配置文件(隐藏文件)? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /home/*; do
	[ -d "$i" ] || continue
		for j in "$i"/.*; do
		[ "$j" = "$i/." ] && continue
		[ "$j" = "$i/.." ] && continue
		echo "${j#/}" >> $exclude
		done
	done
	fi

	echoreden "Do you want to exclude the local repository of retrieved package files in /var/cache/apt/archives/ ? (y/n)"
	echoredcn "是否排除已下载软件包在 /var/cache/apt/archives/ 里的本地缓存 ? (y/n)"
	read yn
	if [ "$yn" = y ]; then
	for i in /var/cache/apt/archives/*.deb; do
	[ -e "$i" ] && echo "${i#/}" >> $exclude
	done
	for i in /var/cache/apt/archives/partial/*; do
	[ -e "$i" ] && echo "${i#/}" >> $exclude
	done
	fi

	echoreden "(For advanced users only) Specify other files/folders you want to exclude from the backup, one file/folder per line. You can drag and drop from Nautilus. End with an empty line.\nNote that the program has automatically excluded all removable media, windows partitions, manually mounted devices, files under /proc, /sys, /tmp, the /host contents of a wubi install, etc. So in most cases you can just hit enter now.\nIf you exclude important system files/folders, the backup will fail to restore."
	echoredcn "(高级用户功能)指定其他需要排除的文件/目录, 一行写一个。以空行结束。\n可以从 Nautilus 文件管理器拖放至此。\n注意程序已经自动排除所有移动设备, windows 分区, 手动挂载的所有设备, /proc, /sys, /tmp 下的文件, wubi 的 /host 内容, 等等。\n所以在绝大多数情况下你只需要直接回车就可以了。\n如果你排除了重要的系统文件/目录, 不要指望你的备份能够工作。"
	read ex
	while [ "$ex" != "" ]; do
	ex=`dequotepath "$ex"`
	[ "${ex#/}" = "$ex" ] && { echoen "You must specify the absolute path"; echocn "请使用绝对路径"; read ex; continue; }
	[ -e "$ex" ] || { echoen "$ex does not exist"; echocn "$ex 并不存在"; read ex; continue; }
	ex="${ex#/}"
	echo $ex >> $exclude
	read ex
	done

	rebuildtree $bindingdir

	for i in /$bindingdir/media/*; do
	ls -ld "$i" | grep "^drwx------ " > /dev/null || continue
	[ `ls -A "$i" | wc -l` = 0 ] || continue
	echo "${i#/$bindingdir/}" >> $exclude
	done

	echoreden "Start to backup?(y/n)"
	echoredcn "开始备份?(y/n)"
	read yn
	[ "$yn" != "y" ] && { destroytree $bindingdir; rm $exclude; exit 1; }
	stime=`date`
	mkdir -p "/$backupdir"
	mksquashfs /$bindingdir "/$backupdir/backup$today.squashfs" -ef $exclude
	destroytree $bindingdir
	rm $exclude
	cp /boot/initrd.img-`uname -r` "/$backupdir"
	cp /boot/vmlinuz-`uname -r` "/$backupdir"
	sqshboot_grubcfg > "/$backupdir/grub.cfg"
	thisuser=`basename ~`
	chown -R $thisuser:$thisuser "/$backupdir" 2> /dev/null
	echoreden "Your backup is ready in /$backupdir. Please read the grub.cfg inside :)"
	echoreden " started at: $stime\nfinished at: `date`"
	echoredcn "已备份至 /$backupdir。请阅读里面的 grub.cfg :)"
	echoredcn "开始于: $stime\n结束于: `date`"
	tput bel
}

dorestore(){
	sqshmnt="/rofs"
	tgtmnt=""
	haswap="no"
	hasboot="no"

	declare -a part oldfstype newfstype partinfo
	packagecheck_r
	echoreden "This will restore your backup. Continue? (y/n)"
	echoredcn "将恢复你的备份。继续? (y/n)"
	read yn
	[ "$yn" != "y" ] && exit 1

	echoreden "Specify the squashfs backup file (absolute path). You can drag the file from Nautilus File Manager and drop it here. If you are booting from the backup squashfs, you can just hit enter, and the squashfs you are booting from will be used."
	echoredcn "指定 squashfs 备份文件 (绝对路径)。可以从 Nautilus 文件管理器拖放。\n从备份的 squashfs 启动的,直接回车即可,将使用本次启动的 squashfs 文件。"
	read backupfile
	[ "$backupfile" = "" ] && { ls /rofs > /dev/null 2>&1 || { echoreden "/rofs not found"; echoredcn "/rofs 没看到。"; exit 1; } }
	[ "$backupfile" != "" ] && { backupfile="`dequotepath "$backupfile"`"; sqshmnt=`new_dir /tmp/sqsh`; mkdir $sqshmnt; mount -o loop "$backupfile" $sqshmnt 2> /dev/null || { echoreden "$backupfile mount error"; echoredcn "$backupfile 挂载不上"; rmdir $sqshmnt; exit 1; } }

	probe_partitions
	setup_target_partitions
	echoreden "Start to format partitions (if any). Continue? (y/n)"
	echoredcn "开始格式化分区 (如果有需要格式化的分区的话)。继续? (y/n)"
	read yn
	[ "$yn" != "y" ] && [ "$sqshmnt" != "/rofs" ] && { umount $sqshmnt; rmdir $sqshmnt; }
	[ "$yn" != "y" ] && exit 1
	umount_target_partitions
	format_target_partitions
	chkuuids
	mount_target_partitions

	echoreden "If you have other partitions for the target system, open another terminal and mount them to appropriate places under $tgt. Then press return."
	echoredcn "如果你为目标系统安排了其他分区, 现在打开另一个终端并挂载它们在 $tgt 下合适的地方。完成后回车。"
	read yn

	tgtmnt=`gettargetmount $tgt`
	defaultgrubdev=`getdefaultgrubdev "$tgtmnt"`
	[ $? = 67 ] && hasboot=yes
	echoreden "Specify the place into which you want to install GRUB."
	echoreden "`expr substr $defaultgrubdev 1 8` and $defaultgrubdev are recommended."
	echoredcn "把 GRUB 安装到哪里?"
	echoredcn "建议安装到 `expr substr $defaultgrubdev 1 8` 或 $defaultgrubdev"
	select grubdev in `listgrubdev`; do
	[ "$grubdev" = "" ] && continue
	break
	done
	grubdev=${grubdev%,*}

	echoreden "The restore process will launch. Continue?(y/n)"
	echoredcn "将马上开始恢复。继续?(y/n)"
	read yn
	[ "$yn" != "y" ] && [ "$sqshmnt" != "/rofs" ] && { umount $sqshmnt; rmdir $sqshmnt; }
	[ "$yn" != "y" ] && { cleartgtmnt; exit 1; }
	stime=`date`
	cp -av $sqshmnt/* $tgt
	rm -f $tgt/etc/initramfs-tools/conf.d/resume
	touch $tgt/etc/mtab
	generate_fstab "$tgt"
	target_cmd "$tgt" update-initramfs -u

	if [ "${grubdev#/dev/}" != "$grubdev" ]; then
	mv $tgt/boot/grub `new_dir $tgt/boot/grub.old` 2> /dev/null
	echo "grub install: installing grub to part ${part[$rootpart]} and disk `expr substr ${part[$rootpart]} 1 8`"
	grub-install --boot-directory=$tgt/boot `expr substr ${part[$rootpart]} 1 8`
	echo "grub mkconfig: making grub.cfg to boot/grub"
	target_cmd "$tgt" grub-mkconfig -o /boot/grub/grub.cfg
	fi

	makelostandfound
	tput bel
	echoreden "Restore started at: $stime,\n       finished at: `date`"
	echoredcn "恢复过程开始于: $stime,\n        结束于: `date`"
	[ "$haswap" = "no" ] && makeswapfile $tgt
	[ "$sqshmnt" != "/rofs" ] && { umount $sqshmnt; rmdir $sqshmnt; }

	echoreden "Enter new hostname or leave blank to use the old one."
	echoredcn "输入新的主机名。留空将使用旧的主机名。"
	oldhostname=`cat $tgt/etc/hostname`
	echoreden "old hostname: $oldhostname"
	echoreden "new hostname:"
	echoredcn "旧的主机名: $oldhostname"
	echoredcn "新的主机名:"
	read newhostname
	[ "$newhostname" != "" ] && { echo $newhostname > $tgt/etc/hostname; sed -i "s/\t$oldhostname/\t$newhostname/g" $tgt/etc/hosts; }

	for i in `ls $tgt/home`; do
	[ -d $tgt/home/$i ] || continue
	target_cmd "$tgt" id $i 2> /dev/null | grep "$i" > /dev/null || continue
	echoreden "Do you want to change the name of user $i? (y/n)"
	echoredcn "是否改变用户名 $i? (y/n)"
	read yn
	[ "$yn" != "y" ] && continue
	echoreden "new username:"
	echoredcn "新的用户名:"
	read newname
		while target_cmd "$tgt" id $newname 2> /dev/null | grep "$newname" > /dev/null; do
		echoreden "$newname already exists"
		echoreden "new username:"
		echoredcn "$newname 已存在"
		echoredcn "新的用户名:"
		read newname
		done
	[ -e $tgt/home/$newname ] && mv $tgt/home/$newname `new_dir $tgt/home/$newname`
	target_cmd "$tgt" chfn -f $newname $i
	target_cmd "$tgt" usermod -l $newname -d /home/$newname -m $i
	target_cmd "$tgt" groupmod -n $newname $i
	done

	for i in `ls $tgt/home`; do
	[ -d $tgt/home/$i ] || continue
	target_cmd "$tgt" id $i 2> /dev/null | grep "$i" > /dev/null || continue
	echoreden "Do you want to change the password of user $i? (y/n)"
	echoredcn "是否改变用户 $i 的密码? (y/n)"
	read yn
		while [ "$yn" = "y" ]; do
		target_cmd "$tgt" passwd $i
		echoreden "If the password was not successfully changed, now you have another chance to change it. Do you want to change the password of user $i again? (y/n)"
		echoredcn "如果刚才的密码改变不成功, 你还有机会。是否再次改变用户 $i 的密码? (y/n)"
		read yn
		done
	done

	rm -f $tgt/etc/blkid.tab
	[ "${part[$usrlocalpart]}" != "" ] && umount ${part[$usrlocalpart]}
	[ "${part[$homepart]}" != "" ] && umount ${part[$homepart]}
	[ "${part[$bootpart]}" != "" ] && umount ${part[$bootpart]}
	[ "${part[$tmppart]}" != "" ] && umount ${part[$tmppart]}
	[ "${part[$usrpart]}" != "" ] && umount ${part[$usrpart]}
	[ "${part[$varpart]}" != "" ] && umount ${part[$varpart]}
	[ "${part[$srvpart]}" != "" ] && umount ${part[$srvpart]}
	[ "${part[$optpart]}" != "" ] && umount ${part[$optpart]}
	umount ${part[$rootpart]} || { echoreden "Please umount $tgt yourself"; echoredcn "请自行卸载 $tgt"; }

	echoreden "Done! Enjoy:)"
	echoredcn "搞定了 :)"
}


generate_fstab1(){
	local targetfstab="$*/etc/fstab"

	echo "# /etc/fstab: static file system information." > "$targetfstab"
	echo "#" >> "$targetfstab"
	echo "# <file system> <mount point>   <type>  <options>       <dump>  <pass>" >> "$targetfstab"
	uuid="`$VOL_ID --uuid $part_root`"
	partition="UUID=$uuid"
	mntpnt="/"
	fs="ext4"
	mntoption="relatime,errors=remount-ro"
	fsckorder="1"
	echo "$partition $mntpnt $fs $mntoption 0 $fsckorder" >> "$targetfstab"
}


makeswapfile1(){
	
	swapsize=$SWAP_SIZE
	local sf=`new_dir $*/swap.img`
	echoreden "Generating swap file..."
	dd if=/dev/zero of=$sf bs=1M count=$swapsize
	mkswap $sf
	echo "${sf#$*}  none  swap  sw  0 0" >> "$*/etc/fstab"
}

doinstall(){

	CONF_FILE=/cdrom/config/lub_auto_install.conf
	cd /root
#	source config
	if [ -f "$CONF_FILE" ]; then
		echo "$CONF_FILE exist, continue"
	else
		echo "$CONF_FILE does not exist, exit"
		exit 1
	fi

	source $CONF_FILE
#	parted
	echo "partition $INSTALL_DISK"
	sudo ./partition.sh $INSTALL_DISK
	part_root=$INSTALL_DISK'2'
#	check uuid
	chkuuids
#	mkdir
	echo "mk source and target dirs"
	dir_source=/mnt/source
	dir_target=/mnt/target
	mkdir $dir_source
	mkdir $dir_target

#	mount source and target to dir
	echo "mount source file and target disk to dirs"
	mount $part_root $dir_target
	mount -t squashfs $INSTALL_FILE $dir_source

#	start to install
	echo "copy files to target dir"
	cp -av $dir_source/* $dir_target
	
#	resume
	rm -f $dir_target/etc/initramfs-tools/conf.d/resume
	touch $dir_target/etc/mtab
	echo "generate fstab"
	generate_fstab1 "$dir_target"
	echo "update initramfs"
	target_cmd "$dir_target" update-initramfs -u

#	install grub
	echo "grub install: installing grub to part $INSTALL_DISK"
	grub-install --boot-directory=$dir_target/boot $INSTALL_DISK
	echo "grub mkconfig: making grub.cfg to $dir_target/boot/grub"
	target_cmd "$dir_target" grub-mkconfig -o /boot/grub/grub.cfg

	makeswapfile1 $dir_target
#	compete
	echo "umount source and target dirs"
	umount $dir_target
	umount $dir_source
	echo "installation complete, please repower and remove usb stick"
}

echohelpen(){
[ $lang = "en" ] && echo "This program can backup your running ubuntu system to a compressed, bootable squashfs file. When you want to restore, boot the squashfs backup and run this program again. You can also restore the backup to another machine. And with this script you can migrate ubuntu system on a virtual machine to physical partitions.

Install:
Just copy this script anywhere and allow execution of the script.

Use:
to backup
sudo ./lub -b
to restore
sudo ./lub -r"
}

echohelpcn(){
[ $lang = "cn" ] && echo "本程序将帮助你备份运行中的 ubuntu 系统为一个可启动的 squashfs 压缩备份文件。
要恢复的时候, 从备份文件启动并再次运行本程序。
可以把备份文件恢复到另一台机器。
可以把虚拟机里的 ubuntu 迁移到真机。

安装:
只要拷贝此脚本到任何地方并赋予执行权限即可。

使用:
备份
sudo ./lub -b
恢复
sudo ./lub -r"
}


ls /sbin/vol_id > /dev/null 2>&1 && VOL_ID=vol_id || VOL_ID=VOL_ID
##echo -e "\033[31me\033[0mnglish/\033[31mc\033[0mhinese?"
echo "live ubuntu backup and restore"
##read lang
##[ "$lang" = "c" ] && lang=cn || lang=en
lang=en
[ "$lang" = "cn" ] && today=`date +%Y.%m.%d` || today=`date +%d.%m.%Y`
[ "$lang" = "cn" ] && version="V2.2, 2009年11月4日" || version="V2.2, Nov 4th,2009"
[ "$*" = -h ] && { echoen "Root privileges are required for running this program.";echocn "备份和恢复需要 root 权限。";echohelpen; echohelpcn; exit 0; }
[ "$*" = -l ] && { dobackup; exit 0; }
[ "$*" = -r ] && { dorestore; exit 0; }
[ "$*" = -i ] && { doinstall; exit 0; }
[ "$*" = -b ] && { dobackup1; exit 0; }
[ "$*" = -t ] && { sqshboot_grubcfg > "grub.cfg"; exit 0; }
exit 1

