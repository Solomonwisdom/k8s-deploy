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

check_parm "Enter the IP address of master-01: " ${CP0_IP} 
if [ $? -eq 1 ]; then
	read CP0_IP
fi
check_parm "Enter the IP address of master-02: " ${CP1_IP}
if [ $? -eq 1 ]; then
	read CP1_IP
fi
check_parm "Enter the IP address of master-03: " ${CP2_IP}
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
check_parm "Enter the VIP: " ${VIP}
if [ $? -eq 1 ]; then
	read VIP
fi
check_parm "Enter the Net Interface: " ${NET_IF}
if [ $? -eq 1 ]; then
	read NET_IF
fi
check_parm "Enter the cluster CIDR: " ${CIDR}
if [ $? -eq 1 ]; then
	read CIDR
fi

echo """
cluster-info:
  master-01:        ${CP0_IP}
  master-02:        ${CP1_IP}
  master-02:        ${CP2_IP}
  worker-01:        ${CP3_IP}
  worker-02:        ${CP4_IP}
  VIP:              ${VIP}
  Net Interface:    ${NET_IF}
  CIDR:             ${CIDR}
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

cat <<EOF > /etc/docker/daemon.json
{
    "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF 
mkdir -p ~/ikube/tls
echo "============Kubernetes Configuration Begin============"
for index in 0 1 2 3 4; do
    ip=${IPS[${index}]}
    scp /etc/docker/daemon.json $ip:/etc/docker/daemon.json
    ssh ${ip} "
    systemctl daemon-reload
    systemctl restart docker"
done
for index in 0 1 2 3 4; do
    ip=${IPS[${index}]}
    ssh ${ip} "
    echo 'LANG=\"en_US.UTF-8\"' >> /etc/profile;source /etc/profile #修改系统语言
    ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime # 修改时区（如果需要修改）
    docker login --username=15605213809 registry.cn-hangzhou.aliyuncs.com -p Wwws85583813"
    sleep 4
done

echo """
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
kubernetesVersion: v1.15.0
controlPlaneEndpoint: \"${VIP}:8443\"
imageRepository: registry.cn-hangzhou.aliyuncs.com/google_containers
networking:
  podSubnet: ${CIDR}
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
mode: ipvs
""" > /etc/kubernetes/kubeadm-config.yaml

kubeadm init --config /etc/kubernetes/kubeadm-config.yaml
mkdir -p $HOME/.kube
cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config
kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml
JOIN_CMD=`kubeadm join 10.130.29.83:8443 --token qq1z4g.k63o2f4a7g9xdou3 \
    --discovery-token-ca-cert-hash sha256:0f03daf6b8b4c5b6fe9066cff8c88d780e6679f780f508e6934ef3fc069c4b27 \
    --control-plane `

echo "------>>>>>>>Cluster add master begin."
for index in 1 2; do
  ip=${IPS[${index}]}
  ssh $ip "mkdir -p /etc/kubernetes/pki/etcd; mkdir -p ~/.kube/"
  scp /etc/kubernetes/pki/ca.crt $ip:/etc/kubernetes/pki/ca.crt
  scp /etc/kubernetes/pki/ca.key $ip:/etc/kubernetes/pki/ca.key
  scp /etc/kubernetes/pki/sa.key $ip:/etc/kubernetes/pki/sa.key
  scp /etc/kubernetes/pki/sa.pub $ip:/etc/kubernetes/pki/sa.pub
  scp /etc/kubernetes/pki/front-proxy-ca.crt $ip:/etc/kubernetes/pki/front-proxy-ca.crt
  scp /etc/kubernetes/pki/front-proxy-ca.key $ip:/etc/kubernetes/pki/front-proxy-ca.key
  scp /etc/kubernetes/pki/etcd/ca.crt $ip:/etc/kubernetes/pki/etcd/ca.crt
  scp /etc/kubernetes/pki/etcd/ca.key $ip:/etc/kubernetes/pki/etcd/ca.key
  scp /etc/kubernetes/admin.conf $ip:/etc/kubernetes/admin.conf
  scp /etc/kubernetes/admin.conf $ip:~/.kube/config

  ssh ${ip} "${JOIN_CMD} --control-plane"
done

echo "------>>>>>>>Cluster add master finished."
echo "------>>>>>>>Cluster add worker begin."
for index in 1 2; do
  ip=${IPS[${index}]}
  ssh ${ip} "${JOIN_CMD}"
done

echo "------>>>>>>>Cluster add woker finished."
echo "============Kubernetes Configuration End============"
