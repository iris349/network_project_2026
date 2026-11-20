#!/bin/bash
# 통합 및 보안 검증 스크립트
# 사용법: ./tests/integration_test.sh   (프로젝트 루트에서 실행, .env 필요)

cd "$(dirname "$0")/.." || exit 1
set -a; [ -f .env ] && . ./.env; set +a

FW_EDGE_IP="172.28.0.2"
WEB_IP="172.29.0.10"
TEST_IP="172.28.0.50"          # 비인가 사용자 역할
WEB_PORT="${WEB_PORT:-80}"
SSH_PORT="${SSH_PORT:-2222}"
EDGE_NET="$(docker network ls --filter name=edge-net --format '{{.Name}}' | head -1)"
SSH_OPTS="-p $SSH_PORT -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -o NumberOfPasswordPrompts=1"

PASS=0; FAIL=0
check() {  # check "이름" 종료코드(0=통과)
  if [ "$2" -eq 0 ]; then echo "[PASS] $1"; PASS=$((PASS+1))
  else echo "[FAIL] $1"; FAIL=$((FAIL+1)); fi
}
as_outsider() { docker run --rm --network "$EDGE_NET" --ip "$TEST_IP" alpine "$@"; }

echo "===== 통합 및 보안 검증 ($(date '+%F %T')) ====="

# 1. 컨테이너 실행
docker compose ps --status running --format '{{.Service}}' | sort | tr '\n' ' ' | grep -q "firewall webserver"
T1=$?; check "1. Compose 실행 (firewall, webserver Up)" $T1

# 2. 외부 사용자 웹 접속
curl -s -o /dev/null -w '%{http_code}' -m 5 "http://localhost:${WEB_PORT}" | grep -q 200
check "2-a. 호스트에서 웹 접속 (방화벽 경유, HTTP 200)" $?

# 대조군: 비인가 컨테이너가 방화벽의 웹(80)에는 접속 가능해야 함
# (이게 실패하면 아래 '차단' 테스트는 의미가 없으므로 모두 FAIL 처리)
CONTROL=1
if [ -n "$EDGE_NET" ] && as_outsider wget -T3 -qO- "http://${FW_EDGE_IP}/" >/dev/null 2>&1; then CONTROL=0; fi
check "2-b. 외부망 사용자가 방화벽 경유로 웹 접속 (테스트 대조군)" $CONTROL

# 3. 웹서버 직접 접근 차단
[ -z "$(docker compose port webserver 80 2>/dev/null | grep -v ':0$')" ]
check "3-a. 웹서버 포트가 호스트에 공개되지 않음" $?
[ $CONTROL -eq 0 ] && ! as_outsider wget -T3 -qO- "http://${WEB_IP}/" >/dev/null 2>&1
check "3-b. 외부망에서 웹서버 직접 접근 차단" $?

# 4. 포트 스캔 (외부망 기준: 80만 open이어야 함)
SCAN=""
[ $CONTROL -eq 0 ] && SCAN=$(as_outsider sh -c "apk add -q nmap >/dev/null 2>&1 && nmap -Pn -p 1-1024 ${FW_EDGE_IP}")
echo "$SCAN" | grep -q '^80/tcp *open'
check "4-a. 포트 스캔: 80 open 확인" $?
OTHERS=$(echo "$SCAN" | grep -E '^[0-9]+/tcp +open' | grep -v '^80/tcp')
echo "$SCAN" | grep -q "Host is up" && [ -z "$OTHERS" ]
check "4-b. 포트 스캔: 80 외 열린 포트 없음" $?

# 5. 관리자 SSH 접속 (허용 IP에서 성공)
if command -v sshpass >/dev/null; then
  sshpass -p "$ADMIN_PASSWORD" ssh $SSH_OPTS admin@localhost 'echo ok' 2>/dev/null | grep -q ok
  check "5. 관리자 SSH 접속 성공" $?
else
  echo "[SKIP] 5. sshpass 미설치 (sudo apt install -y sshpass)"
fi

# 6. 비인가 접근 차단
[ $CONTROL -eq 0 ] && ! as_outsider sh -c "nc -w3 ${FW_EDGE_IP} 22 </dev/null | grep -q SSH"
check "6-a. 비인가 IP의 SSH 접속 차단" $?
if command -v sshpass >/dev/null; then
  OUT=$(sshpass -p "wrong-password" ssh $SSH_OPTS admin@localhost 'echo ok' 2>&1)
  echo "$OUT" | grep -q "Permission denied"
  check "6-b. 틀린 비밀번호 로그인 거부 (Permission denied 확인)" $?
fi

# 7. 재시작 후 설정 유지 (1번이 통과한 경우에만 의미가 있음)
if [ $T1 -eq 0 ]; then
  docker compose restart >/dev/null 2>&1; sleep 6
  curl -s -o /dev/null -w '%{http_code}' -m 5 "http://localhost:${WEB_PORT}" | grep -q 200
  check "7-a. 재시작 후 웹 접속 유지" $?
  docker compose exec -T firewall iptables -S INPUT | grep -q -- '-P INPUT DROP'
  check "7-b. 재시작 후 방화벽 기본 정책(DROP) 유지" $?
else
  check "7. 재시작 테스트 (1번 실패로 실행 불가)" 1
fi

echo "===== 결과: PASS ${PASS} / FAIL ${FAIL} ====="
[ "$FAIL" -eq 0 ]
