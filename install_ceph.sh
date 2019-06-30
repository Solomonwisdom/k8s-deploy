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

echo "============Ceph Installation Begin============"
cat << EOF > /etc/yum.repos.d/ceph.repo
[ceph]
name=Ceph packages for x86_64
baseurl=https://mirrors.ustc.edu.cn/ceph/rpm-nautilus/el7/x86_64
enabled=1
priority=2
gpgcheck=1
gpgkey=https://mirrors.ustc.edu.cn/ceph/keys/release.asc

[ceph-noarch]
name=Ceph noarch packages
baseurl=https://mirrors.ustc.edu.cn/ceph/rpm-nautilus/el7/noarch
enabled=1
priority=2
gpgcheck=1
gpgkey=https://mirrors.ustc.edu.cn/ceph/keys/release.asc

[ceph-source]
name=Ceph source packages
baseurl=https://mirrors.ustc.edu.cn/ceph/rpm-nautilus/el7/SRPMS
enabled=0
priority=2
gpgcheck=1
gpgkey=https://mirrors.ustc.edu.cn/ceph/keys/release.asc
EOF
for index in 0 1 2 3 4; do
    ip=${IPS[${index}]}
    scp /etc/yum.repos.d/ceph.repo $ip:/etc/yum.repos.d/ceph.repo
    ssh ${ip} "
    yum install -y yum-plugin-priorities
    yum install -y snappy leveldb gdisk python-argparse gperftools-libs
    yum install -y ceph-deploy
    yum install -y ntp ntpdate ntp-doc
    yum install -y ceph
    systemctl enable ntpd && systemctl start ntpd
    useradd -d /home/cepher -m cepher
    echo \"cepher ALL = (root) NOPASSWD:ALL\" | tee /etc/sudoers.d/cepher
    chmod 0440 /etc/sudoers.d/cepher"
done
ceph-deploy new kube-2 kube-3 kube-4
for index in 0 1 2 3 4; do 
    ip=${IPS[${index}]}; ssh ${ip} "
    sudo yum install -y ceph-deploy ceph ceph-radosgw"; 
done
ceph-deploy mon create-initial
ceph-deploy admin kube-1 kube-2 kube-3 kube-4 kube-5
ceph-deploy mgr create kube-4 kube-5
echo "============Kubeadm Installation End============"
