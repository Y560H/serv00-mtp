#!/bin/bash

echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
echo "serv00 MTproxy for telegram"
FILE_URL="https://github.com/9seconds/mtg/releases/download/v2.1.7/mtg-2.1.7-freebsd-amd64.tar.gz"
DIR_NAME="mtg-2.1.7-freebsd-amd64"


echo "正在下载 mtg 文件..."
wget -q $FILE_URL -O mtg.tar.gz

echo "解压中..."
tar -xzf mtg.tar.gz
cd mtg-2.1.7-freebsd-amd64


read -p "输入你的服务器名(例:s1.serv00.com): " host
read -p "输入端口号(1025-60000): " port


secret=$(./mtg generate-secret --hex $host)

mtproto_url="https://t.me/proxy?server=${host}&port=${port}&secret=${secret}"

#
echo "代理在线!"
echo "使用此链接在 Telegram 中访问代理"
echo "$mtproto_url"
echo " "
echo "祝你"
echo "玩的开心"
nohup ./mtg simple-run -n 1.1.1.1 -t 30s -a 1MB 0.0.0.0:${port} ${secret} -c 8192 > mtg.log 2>&1 &