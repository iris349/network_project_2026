FROM alpine:3.20

# 방화벽 및 SSH 도구 설치
RUN apk add --no-cache iptables iproute2 openssh

# 관리자 계정 생성
RUN adduser -D admin

# SSH 비밀번호 인증을 허용하되 root 로그인은 차단
RUN sed -i 's/^#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && echo 'PermitRootLogin no' >> /etc/ssh/sshd_config \
    && echo 'AllowUsers admin' >> /etc/ssh/sshd_config

# 방화벽 설정 스크립트 복사
COPY firewall.sh /firewall.sh
RUN chmod +x /firewall.sh

# 컨테이너 시작 시 SSH 키 생성, 방화벽 적용, SSH 서버 실행
CMD ["/bin/sh", "-c", "echo \"admin:${ADMIN_PASSWORD}\" | chpasswd && ssh-keygen -A && /firewall.sh && exec /usr/sbin/sshd -D -e"]
