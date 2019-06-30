#/bin/bash

function check_parm()
{
  if [ "${2}" == "" ]; then
    echo -n "${1}"
    return 1
  else
    return 0
  fi
}

if [ -f ./cluster-info ]; then
	source ./cluster-info 
fi

check_parm "Enter the IP address of node-01: " ${CP0_IP} 
if [ $? -eq 1 ]; then
	read CP0_IP
fi
check_parm "Enter the IP address of node-02: " ${CP1_IP}
if [ $? -eq 1 ]; then
	read CP1_IP
fi
check_parm "Enter the IP address of node-03: " ${CP2_IP}
if [ $? -eq 1 ]; then
	read CP2_IP
fi
check_parm "Enter the IP address of node-04: " ${CP3_IP} 
if [ $? -eq 1 ]; then
	read CP3_IP
fi
check_parm "Enter the IP address of node-05: " ${CP4_IP}
if [ $? -eq 1 ]; then
	read CP4_IP
fi

echo """
cluster-info:
  node-01:        ${CP0_IP}
  node-02:        ${CP1_IP}
  node-03:        ${CP2_IP}
  node-04:        ${CP3_IP}
  node-05:        ${CP4_IP}
"""
echo -n 'Please print "yes" to continue or "no" to cancel: '
read AGREE
while [ "${AGREE}" != "yes" ]; do
	if [ "${AGREE}" == "no" ]; then
		exit 0;
	else
		echo -n 'Please print "yes" to continue or "no" to cancel: '
		read AGREE
	fi
done

IPS=(${CP0_IP} ${CP1_IP} ${CP2_IP} ${CP3_IP} ${CP4_IP})

echo "============Docker Installation Begin============"
echo """
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
172.16.1.131 kube-1
172.16.1.132 kube-2
172.16.1.133 kube-3
172.16.1.134 kube-4
172.16.1.135 kube-5
114.212.189.139 registry.njuics.cn
""" > /etc/hosts
echo """
ipvs_modules=\"ip_vs ip_vs_lc ip_vs_wlc ip_vs_rr ip_vs_wrr ip_vs_lblc ip_vs_lblcr ip_vs_dh ip_vs_sh ip_vs_nq ip_vs_sed ip_vs_ftp nf_conntrack\"
for kernel_module in \${ipvs_modules}; do
    /sbin/modinfo -F filename \${kernel_module} > /dev/null 2>&1
    if [ \$? -eq 0 ]; then
        /sbin/modprobe \${kernel_module}
    fi
done
""" > /etc/sysconfig/modules/ipvs.modules
for index in 0 1 2 3 4; do
    ip=${IPS[${index}]}
    scp /etc/hosts $ip:/etc/hosts
    scp /etc/sysconfig/modules/ipvs.modules $ip:/etc/sysconfig/modules/ipvs.modules
    ssh ${ip} "
    yum -y install ntpdate
    ntpdate cn.pool.ntp.org  
    yum remove -y docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-engine
    yum install -y yum-utils \
                    device-mapper-persistent-data \
                    lvm2 vim
    yum-config-manager \
        --add-repo \
        https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo 

    yum install -y docker-ce-18.09.6-3.el7
    systemctl enable docker && systemctl start docker
    chmod 755 /etc/sysconfig/modules/ipvs.modules && bash /etc/sysconfig/modules/ipvs.modules"
done

echo "============Docker Installation End============"

echo "============Kubeadm Installation begin============"
echo """
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
exclude=kube*
""" > /etc/yum.repos.d/kubernetes.repo
echo """
net.ipv4.ip_forward=1
net.bridge.bridge-nf-call-iptables=1
net.ipv4.neigh.default.gc_thresh1=4096
net.ipv4.neigh.default.gc_thresh2=6144
net.ipv4.neigh.default.gc_thresh3=8192
""" > /etc/sysctl.conf
echo """
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 10
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.neigh.default.gc_stale_time = 120
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.default.arp_announce = 2
net.ipv4.conf.lo.arp_announce = 2
net.ipv4.conf.all.arp_announce = 2
net.ipv4.ip_forward = 1
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn_backlog = 1024
net.ipv4.tcp_synack_retries = 2
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.netfilter.nf_conntrack_max = 2310720
fs.inotify.max_user_watches=89100
fs.may_detach_mounts = 1
fs.file-max = 52706963
fs.nr_open = 52706963
net.bridge.bridge-nf-call-arptables = 1
vm.swappiness = 0
vm.overcommit_memory=1
vm.panic_on_oom=0
""" > /etc/sysctl.d/k8s.conf
for index in 0 1 2 3 4; do
    ip=${IPS[${index}]}
    scp /etc/yum.repos.d/kubernetes.repo ${ip}:/etc/yum.repos.d/kubernetes.repo
    scp /etc/sysctl.conf ${ip}:/etc/sysctl.conf
    scp /etc/sysctl.d/k8s.conf ${ip}:/etc/sysctl.d/k8s.conf
    ssh ${ip} "
    docker login -u solomonfield -p whg19962017
    systemctl stop firewalld
    systemctl disable firewall d

    # Set SELinux in permissive mode (effectively disabling it)
    setenforce 0
    sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config
    swapoff -a
    sed -i 's/.*swap.*/#&/' /etc/fstab

    sysctl -p
    sysctl --system
    yum install -y kubelet-1.15.0-0 kubeadm-1.15.0-0 kubectl-1.15.0-0 --disableexcludes=kubernetes
    systemctl enable --now kubelet"
done
echo "============Kubeadm Installation End============"
