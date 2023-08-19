# lub（live ubuntu backup）
## 简介
本程序将帮助你备份运行中的 ubuntu 系统为一个可启动的 squashfs 压缩备份文件。
要恢复的时候, 从备份文件启动并再次运行本程序。
可以把备份文件恢复到另一台机器。
可以把虚拟机里的 ubuntu 迁移到真机。

## 安装:
只要拷贝此脚本到任何地方并赋予执行权限即可。
我喜欢把它放在 /usr/local/bin 里面, 这样每次运行的时候就不用写绝对路径了。

## 使用:
必须使用sudo才能确保有足够的权限，否则某些文件会丢失。
> 备份
sudo ./lub -b

> 恢复
sudo ./lub -r

## 依赖
* squashfs-tools，打包squashfs文件
* casper，live cd 启动需要(不要安装 lupin-casper，它已经被弃用。)
* parted，分区脚本需要

可以使用apt安装

`sudo apt install squashfs-tools casper  parted`

## 备份:
sudo ./lub -b

根据提示进行就可以了。
你可以指定存放备份的路径, 以及需要排除的文件和目录。
小心: 你必须确定有足够的空间来存放备份。
脚本将会生成启动所需的另外几个文件。
阅读在备份存放目录生成的 grub.cfg，里面会详细告诉你如何从备份文件直接启动。
## 制作liveCD
* 使用rufus制作gurb2.0启动盘。
* U盘根目录新建casper文件夹，copy *.squashfs, initrd, vmlinuz到casper文件夹。
* copy boot文件夹到U盘中。
* copy grub.cfg到boot/grub文件夹中。
## 恢复:
启动了 live ubuntu backup 之后, 打开一个终端输入

sudo ./lub -r

并根据提示进行恢复就可以了。
注意:此脚本并不提供分区功能(只能格式化分区但不能创建,删除分区或调整分区大小)。
只能恢复备份到已有的分区。
另外如果分区表有错误, 将不允许恢复备份，直到错误被修复。
你可以指定若干分区和它们的挂载点。
如果没有 swap 分区, 可以为你创建一个 swap 文件 (如果你这样要求的话)。
会自动生成新的 fstab 并安装 grub。
如果有必要, 还可以改变主机名, 用户名和密码。