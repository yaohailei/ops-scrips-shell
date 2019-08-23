#! /bin/bash
ps -e -o stat,ppid|egrep '^[Zz]'|awk '{print $2}'|while read line
do
#echo "$line"
kill -9 $line
done
