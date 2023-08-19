#分区工具
#默认GPT分区 + BIOS + /root
#使用BIOS引导GPT的分区情况（BIOS/GPT）下，必须使用 BIOS 启动分区
#GRUB将core.img嵌入到这个分区。

lang=cn
[ $lang = "cn" ] && echo "Partition shell runing:"
[ $lang = "en" ] && echo "正在执行分区:"

BIOS_START=1M
BIOS_END=2M

P1_START=2M
P1_END=100%

#P2_START=10G
#P2_END=20G

#P3_START=20G
#P3_END=100%

parted --script $* mklabel gpt \
 mkpart primary ext4 $BIOS_START $BIOS_END \
 set 1 bios_grub on \
 mkpart primary ext4 $P1_START $P1_END \
# mkpart primary ext4 $P2_START $P2_END \
# mkpart primary ext4 $P3_START $P3_END \

mkfs.ext4 $*'1'
mkfs.ext4 $*'2'
#mkfs.ext4 $*'3'
#mkfs.ext4 $*'4'
