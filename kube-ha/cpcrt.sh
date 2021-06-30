USER=root # customizable
CONTROL_PLANE_IPS="210.28.132.170"
for host in ${CONTROL_PLANE_IPS}; do
    scp -P 22 /etc/kubernetes/pki/ca.crt "${USER}"@$host:/etc/kubernetes/pki/ca.crt
    scp -P 22 /etc/kubernetes/pki/ca.key "${USER}"@$host:/etc/kubernetes/pki/ca.key
    scp -P 22 /etc/kubernetes/pki/sa.key "${USER}"@$host:/etc/kubernetes/pki/sa.key
    scp -P 22 /etc/kubernetes/pki/sa.pub "${USER}"@$host:/etc/kubernetes/pki/sa.pub
    scp -P 22 /etc/kubernetes/pki/front-proxy-ca.crt "${USER}"@$host:/etc/kubernetes/pki/front-proxy-ca.crt
    scp -P 22 /etc/kubernetes/pki/front-proxy-ca.key "${USER}"@$host:/etc/kubernetes/pki/front-proxy-ca.key
    scp -P 22 /etc/kubernetes/pki/etcd/ca.crt "${USER}"@$host:/etc/kubernetes/pki/etcd/ca.crt
    scp -P 22 /etc/kubernetes/pki/etcd/ca.key "${USER}"@$host:/etc/kubernetes/pki/etcd/ca.key
done