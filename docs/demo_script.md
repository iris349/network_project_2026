# 시연 스크립트 (녹화 순서)

사전 준비: 터미널 글자 크게, 창 넓게. 장면마다 `clear` 실행. `.env` 내용은 화면에 띄우지 않는다.

```bash
cd ~/network_project_2026
docker compose down -v
ssh-keygen -R "[localhost]:2222" 2>/dev/null
EDGE=network_project_2026_edge-net
```

## 1. 구성 소개
```bash
cat docker-compose.yml
sed -n '1,45p' firewall/firewall.sh
```

## 2. 기동
```bash
docker compose up -d --build
docker compose ps
docker compose logs firewall | head -30
docker compose exec firewall iptables -L -n -v --line-numbers
docker compose exec firewall iptables -t nat -L PREROUTING -n -v
```
확인: 방화벽만 80, 2222 공개 / 웹서버는 80/tcp만 표시 / INPUT, FORWARD 기본 정책 DROP

## 3. 웹서비스 (TCP 80)
브라우저에서 `http://localhost` 접속 후 화면 캡처 (주소창 포함)
```bash
curl -I http://localhost
curl -i -X POST http://localhost | head -3
```
확인: 200 OK, 보안 헤더, POST는 405

## 4. 웹서버 직접 접근 차단
```bash
docker compose port webserver 80
docker run --rm --network $EDGE --ip 172.28.0.50 alpine wget -T3 -qO- http://172.29.0.10/ ; echo "exit=$?"
docker run --rm --network $EDGE --ip 172.28.0.50 alpine wget -T3 -qO- http://172.28.0.2/ | head -3
```
확인: 직접 접근은 timeout(exit=1), 방화벽 경유는 HTML 수신

## 5. 포트 스캔
```bash
nmap -Pn -p 22,80,443,2222,3306,8080 localhost
docker run --rm --network $EDGE --ip 172.28.0.50 alpine sh -c 'apk add -q nmap >/dev/null && nmap -Pn -p 1-1024 172.28.0.2'
```
확인: 호스트는 80, 2222만 open / 외부망 스캔은 80만 open, 나머지 filtered

## 6. 관리자 접근통제
```bash
ssh -p 2222 admin@localhost
```
비밀번호 입력 후 로그인 화면 확인, `exit`
```bash
ssh -p 2222 -o PreferredAuthentications=password -o PubkeyAuthentication=no -o NumberOfPasswordPrompts=1 admin@localhost
```
일부러 틀린 비밀번호 입력 → Permission denied
```bash
docker compose exec firewall iptables -L INPUT -n -v
docker run --rm --network $EDGE --ip 172.28.0.50 alpine sh -c 'nc -w3 172.28.0.2 22 </dev/null; echo exit=$?'
docker compose exec firewall iptables -L INPUT -n -v
docker compose logs firewall | grep -i "failed"
```
확인: 비인가 IP는 배너 없이 exit=1 / 마지막 DROP 카운터가 증가 / 실패 로그 기록

## 7. 재시작 및 재생성 후 유지
```bash
docker compose restart && sleep 5
docker compose ps
curl -I http://localhost
ssh -p 2222 admin@localhost
```
```bash
docker compose down && docker compose up -d && sleep 5
curl -I http://localhost
ssh-keygen -R "[localhost]:2222"
ssh -p 2222 admin@localhost
```

## 8. 통합 테스트
```bash
./tests/integration_test.sh
```
확인: PASS 12 / FAIL 0
```bash
docker compose stop firewall
./tests/integration_test.sh
docker compose up -d
```
확인: 방화벽 중지 시 FAIL로 감지 (테스트가 실제 상태를 반영함)
