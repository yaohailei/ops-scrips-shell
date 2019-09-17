#!/bin/sh
# 将处理成列的dnsname输入到文件中
cat tmp.txt.bak|while read line
do
  v6=`dig +short @2001:da8:1031:414::9 ${line}.nufe.edu.cn`
  v4=`dig +short @210.28.81.1 ${line}.nufe.edu.cn`
#  echo "$v4"
  if [ "$v6" != "$v4" ];then
    echo "$line"
  fi
done
