FROM alpine:3.20

# 방화벽, 네트워크, SSH 도구 설치
RUN apk add --no-cache iptables iproute2 openssh

COPY firewall.sh /firewall.sh
RUN chmod +x /firewall.sh

# 방화벽 적용 후 컨테이너 유지
CMD ["/bin/sh", "-c", "/firewall.sh && tail -f /dev/null"]
