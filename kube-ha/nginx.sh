cat << EOF > /etc/nginx/kubernetes/nginx.conf
error_log stderr notice;

worker_processes auto;
events {
  multi_accept on;
  use epoll;
  worker_connections 1024;
}

stream {
    upstream kube_apiserver {
        least_conn;
        server 210.28.132.168:6443;
        server 210.28.132.169:6443;
        server 210.28.132.170:6443;
    }

    server {
        listen        0.0.0.0:9443;
        proxy_pass    kube_apiserver;
        proxy_timeout 10m;
        proxy_connect_timeout 1s;
    }
}
EOF

cat << EOF > /etc/systemd/system/nginx-proxy.service
[Unit]
Description=kubernetes apiserver docker wrapper
Wants=docker.socket
After=docker.service

[Service]
User=root
PermissionsStartOnly=true
ExecStart=/usr/bin/docker run -p 127.0.0.1:9443:6443 \\
                              -v /etc/nginx/kubernetes/:/etc/nginx \\
                              --name nginx-proxy \\
                              --net=host \\
                              --restart=always \\
                              --memory=512M \\
                              nginx:alpine
ExecStartPre=-/usr/bin/docker rm -f nginx-proxy
ExecStop=/usr/bin/docker stop nginx-proxy
Restart=always
RestartSec=15s
TimeoutStartSec=30s

[Install]
WantedBy=multi-user.target
EOF