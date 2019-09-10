#!/bin/bash

# 监测脚本工作目录
BASE_DIR=/usr/local/yeti

# 递归服务类型,支持bind和unbound
TYPE=bind

# 控制文件路径,bind为rndc路径，unbound为unbound-control路径
CONTROL_PROGRAM=/usr/sbin/rndc
# unbound配置文件路径,bind可忽略此选项
DNS_CONF=/home/unbound/usr/local/etc/unbound/unbound.conf

# ipv6根服务器配置清单
IPv6_ROOT_HINT=${BASE_DIR}/config/hint-ipv6.conf
# ipv4默认根配置清单
DEFAULT_ROOT_HINT=${BASE_DIR}/config/hint-default.conf
# 当前使用根服务类型
ROOT_STATUS=${BASE_DIR}/root_v6_status


if [ ! -d ${BASE_DIR} ];then
    mkdir -p ${BASE_DIR}
fi

if [ ! -d ${BASE_DIR}/config ];then
    mkdir ${BASE_DIR}/config
fi

if [ ! -s $ROOT_STATUS ];then
    mkdir $ROOT_STATUS
fi


# 生成ipv6根服务器配置清单
if [ ! -s ${IPv6_ROOT_HINT} ]; then
    cat > ${IPv6_ROOT_HINT} <<V6ROOT
.                       518400  IN      NS      ns-6ors.dns-lab.net.
.                       518400  IN      NS      root.dns-lab.net.
.                       518400  IN      NS      root6.dns-lab.net.
root.dns-lab.net.       518400  IN      AAAA    240c:f:1:32::66
root6.dns-lab.net.      518400  IN      AAAA    240c:6::6
ns-6ors.dns-lab.net.    518400  IN      AAAA    240e:eb:8001:e01::6
V6ROOT
fi


# 生成ipv4根服务器配置清单
if [ ! -s ${DEFAULT_ROOT_HINT} ]; then
    cat >"$DEFAULT_ROOT_HINT" <<V4ROOT
.                       518400  IN      NS      m.root-servers.net.
.                       518400  IN      NS      b.root-servers.net.
.                       518400  IN      NS      c.root-servers.net.
.                       518400  IN      NS      d.root-servers.net.
.                       518400  IN      NS      e.root-servers.net.
.                       518400  IN      NS      f.root-servers.net.
.                       518400  IN      NS      g.root-servers.net.
.                       518400  IN      NS      h.root-servers.net.
.                       518400  IN      NS      a.root-servers.net.
.                       518400  IN      NS      i.root-servers.net.
.                       518400  IN      NS      j.root-servers.net.
.                       518400  IN      NS      k.root-servers.net.
.                       518400  IN      NS      l.root-servers.net.
m.root-servers.net.     518400  IN      A       202.12.27.33
m.root-servers.net.     518400  IN      AAAA    2001:dc3::35
b.root-servers.net.     518400  IN      A       199.9.14.201
b.root-servers.net.     518400  IN      AAAA    2001:500:200::b
c.root-servers.net.     518400  IN      A       192.33.4.12
c.root-servers.net.     518400  IN      AAAA    2001:500:2::c
d.root-servers.net.     518400  IN      A       199.7.91.13
d.root-servers.net.     518400  IN      AAAA    2001:500:2d::d
e.root-servers.net.     518400  IN      A       192.203.230.10
e.root-servers.net.     518400  IN      AAAA    2001:500:a8::e
f.root-servers.net.     518400  IN      A       192.5.5.241
f.root-servers.net.     518400  IN      AAAA    2001:500:2f::f
g.root-servers.net.     518400  IN      A       192.112.36.4
g.root-servers.net.     518400  IN      AAAA    2001:500:12::d0d
h.root-servers.net.     518400  IN      A       198.97.190.53
h.root-servers.net.     518400  IN      AAAA    2001:500:1::53
a.root-servers.net.     518400  IN      A       198.41.0.4
a.root-servers.net.     518400  IN      AAAA    2001:503:ba3e::2:30
i.root-servers.net.     518400  IN      A       192.36.148.17
i.root-servers.net.     518400  IN      AAAA    2001:7fe::53
j.root-servers.net.     518400  IN      A       192.58.128.30
j.root-servers.net.     518400  IN      AAAA    2001:503:c27::2:30
k.root-servers.net.     518400  IN      A       193.0.14.129
k.root-servers.net.     518400  IN      AAAA    2001:7fd::1
l.root-servers.net.     518400  IN      A       199.7.83.42
l.root-servers.net.     518400  IN      AAAA    2001:500:9f::42
V4ROOT
fi



# 检测ipv6根状态
check_v6root_status(){
    local hint="$1"

    if [ -s ${BASE_DIR}/v6soa.txt ];then
        echo "" > ${BASE_DIR}/v6soa.txt
    fi

    egrep -v '^;|^$|NS' ${hint} | awk '{print $NF}' | while read line
    # 循环dig测试ipv6根节点
    do
        dig @${line} +time=1 . soa 1 >> ${BASE_DIR}/v6soa.txt 2>&1
    done

    # 有一个能解析成功测通返回0,全部解析不成功返回1
    if grep -q 'status: NOERROR' ${BASE_DIR}/v6soa.txt; then
        return 0
    else
        return 1
    fi
}



switch_root(){
    if [ $TYPE = unbound ];then
        if [ "$1" = ipv6 ];then
            $CONTROL_PROGRAM -c ${DNS_CONF} stub_add . $(egrep -v '^;|^$|NS' ${IPv6_ROOT_HINT}| awk '{print $NF}') 1>/dev/null 2>&1
        elif [ "$1" = ipv4 ];then
            $CONTROL_PROGRAM -c ${DNS_CONF} stub_add . $(egrep -v '^;|^$|NS' ${DEFAULT_ROOT_HINT}| awk '{print $NF}') 1>/dev/null 2>&1
        else
            exit -1
        fi

    elif [ $TYPE = bind ];then
        if [ "$1" = ipv6 ];then
            line=`egrep -v '^;|^$|NS' ${IPv6_ROOT_HINT}| awk '{print $NF}' | tr "\n" ";"`
            $CONTROL_PROGRAM  delzone .
            $CONTROL_PROGRAM  addzone . '{ type static-stub; server-addresses { '${line}' }; };'
           # $CONTROL_PROGRAM  flush
            $CONTROL_PROGRAM  flushname .
           
        elif [ "$1" = ipv4 ];then
            line=`egrep -v '^;|^$|NS' ${DEFAULT_ROOT_HINT}| awk '{print $NF}' | tr "\n" ";"`
            $CONTROL_PROGRAM  delzone .
            $CONTROL_PROGRAM  addzone . '{ type static-stub; server-addresses { '${line}' }; };'
            #$CONTROL_PROGRAM  flush
            $CONTROL_PROGRAM  flushname .
        else
            exit -1
        fi
    else
        exit -2
    fi
}



main(){
    check_v6root_status $IPv6_ROOT_HINT
    if [ $? = 0 ];then
        if grep -q IPv6_root $ROOT_STATUS; then
            echo "MONITOR: $(date) IPv6 root works well!"
        else
            switch_root ipv6
            echo "IPv6_root" > $ROOT_STATUS
            echo "MONITOR: $(date) IPv6 root is OK, switch to IPv6 root"
        fi
    else
        if grep -q default_root $ROOT_STATUS; then
          echo "MONITOR: $(date) IPv6 root error, IPv4 root is working!"
        else 
          switch_root ipv4
          echo "default_root" > $ROOT_STATUS
          echo "MONITOR: $(date) IPv6 root error, switch to IPv4 root"
        fi
    fi
}

main

