helm install stable/nginx-ingress --name nginx-ingress \
--namespace nginx-ingress --set rbac.create=true,\
defaultBackend.image.repository=registry.njuics.cn/google_containers/defaultbackend-amd64,\
controller.kind=DaemonSet,controller.daemonset.useHostPort=true \
--set-string controller.nodeSelector."controller\.ingress\.io/enabled"="true"
