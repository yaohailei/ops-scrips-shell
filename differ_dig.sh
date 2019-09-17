#!/bin/sh
# 将处理成列的dnsname输入到文件中
cat tmp.txt.bak|while read line
do
  v6=`d1ig @2001:da8:1031:414::9 ${line}.nufe.edu.cn|egrep -v '^$'| egrep -v '^;'|grep -w -E "IN"|grep -w -E "A|AAAA"|awk '{print $5}'|sort|uniq|tr "\n" "|"`
  v4=`dig @210.28.81.1 ${line}.nufe.edu.cn|egrep -v '^$'| egrep -v '^;'|grep -w -E "IN"|grep -w -E "A|AAAA"| awk '{print $5}'|sort|uniq |tr "\n" "|"`
#  echo "$v4"
  if [ "$v6" != "$v4" ];then
    echo "$line no"
  fi
done
