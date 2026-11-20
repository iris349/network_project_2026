#!/bin/sh
WEB_IP="${WEB_IP:-172.29.0.10}"      # 웹서버 IP
ADMIN_IP="${ADMIN_IP:-172.28.0.1}"   # 관리자 IP

# 인터페이스 찾기
EXT_IF=$(ip -o -4 addr | awk '/172\.28\.0\./ {print $2}')   # 외부
INT_IF=$(ip -o -4 addr | awk '/172\.29\.0\./ {print $2}')   # 내부

if [ -z "$EXT_IF" ] || [ -z "$INT_IF" ]; then
  echo "[FW] ERROR: 인터페이스 없음"
  exit 1
fi

# 규칙 초기화
iptables -F
iptables -X
iptables -t nat -F

# 기본 정책: 차단
iptables -P INPUT   DROP
iptables -P FORWARD DROP
iptables -P OUTPUT  ACCEPT

# 루프백, 응답 패킷 허용
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT   -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# 웹: TCP 80 -> 웹서버
iptables -t nat -A PREROUTING -i "$EXT_IF" -p tcp --dport 80 \
         -j DNAT --to-destination "$WEB_IP:80"
iptables -A FORWARD -i "$EXT_IF" -o "$INT_IF" -p tcp -d "$WEB_IP" --dport 80 \
         -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A POSTROUTING -o "$INT_IF" -j MASQUERADE

# 관리자: SSH 22 허용
iptables -A INPUT -i "$EXT_IF" -p tcp -s "$ADMIN_IP" --dport 22 -j ACCEPT

# 나머지 차단
iptables -A INPUT   -j DROP
iptables -A FORWARD -j DROP

echo "[FW] 적용 완료"
iptables -L -n -v
