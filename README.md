# Docker 기반 안전한 Linux 웹서버 구축

Docker 컨테이너로 방화벽과 웹서버를 분리하고, 방화벽을 통해서만 웹서비스(TCP 80)를 제공하며
관리자만 SSH로 접속할 수 있도록 구성한 네트워크 보안 프로젝트입니다.

## 구성

| 컨테이너 | 이미지 | 역할 | 네트워크 / IP |
|---|---|---|---|
| firewall | alpine:3.20 (iptables, sshd) | 외부 진입점, 패킷 필터링, 관리자 SSH | edge-net 172.28.0.2 / backend-net 172.29.0.2 |
| webserver | nginx:alpine | 웹서비스 제공 | backend-net 172.29.0.10 |

- 웹서버는 내부망(backend-net)에만 연결되며 호스트에 포트를 공개하지 않습니다.
- 외부 요청은 방화벽의 TCP 80으로 들어와 DNAT으로 웹서버에 전달됩니다.
- 방화벽은 기본 정책이 DROP이며, 웹(TCP 80)과 관리자 IP의 SSH(TCP 22)만 허용합니다.
- 웹서버는 GET/HEAD만 허용하고, 보안 헤더 적용과 버전 정보 숨김 설정을 사용합니다.

## 실행 방법

사전 요구: Linux, Docker, Docker Compose v2.33 이상 (`gw_priority` 사용)

```bash
git clone https://github.com/iris349/network_project_2026.git
cd network_project_2026
cp .env.example .env        # ADMIN_PASSWORD를 실제 값으로 수정
docker compose up -d --build
docker compose ps
```

### 환경 변수 (.env)

| 변수 | 설명 | 기본값 |
|---|---|---|
| ADMIN_PASSWORD | 관리자(admin) SSH 비밀번호 (필수) | 없음 |
| ADMIN_IP | SSH 접속을 허용할 관리자 IP | 172.28.0.1 |
| WEB_PORT | 호스트에 공개할 웹 포트 | 80 |
| SSH_PORT | 호스트에 공개할 SSH 포트 | 2222 |

`.env`는 Git에 올리지 않습니다 (`.gitignore`).

### 접속

- 웹: `http://<서버 IP>:80`
- 관리자 SSH: `ssh -p 2222 admin@<서버 IP>` (허용된 관리자 IP에서만 가능)

> `ADMIN_IP` 기본값 172.28.0.1은 Docker 호스트에서 접속할 때 방화벽이 보는 출발지 주소입니다.
> 다른 PC를 관리자로 사용할 때는 해당 PC의 IP로 변경하세요.

## 검증

```bash
sudo apt install -y sshpass nmap
./tests/integration_test.sh
```

| # | 검증 항목 | 기대 결과 |
|---|---|---|
| 1 | Docker Compose 실행 | 모든 컨테이너 Up |
| 2 | 외부 사용자 웹 접속 | 방화벽 경유 HTTP 200 |
| 3 | 웹서버 직접 접근 차단 | 호스트 미공개, 외부망 직접 접근 불가 |
| 4 | 포트 스캔 | 80 외 열린 포트 없음 |
| 5 | 관리자 SSH 접속 | 허용 IP에서 로그인 성공 |
| 6 | 비인가 접근 차단 | 다른 IP 차단, 틀린 비밀번호 거부 |
| 7 | 재시작 후 설정 유지 | 웹 접속과 방화벽 기본 정책 유지 |

스크립트는 정상 상태에서 전체 통과(PASS)하고, 방화벽을 중지하면 해당 항목이 실패(FAIL)하도록 확인했습니다.
비인가 외부 사용자는 edge-net에 `172.28.0.50` 주소의 별도 컨테이너를 붙여 재현합니다.

## 참고 사항

- 방화벽이 외부 진입점이 되도록 compose에서 edge-net에 `gw_priority`를 지정했습니다.
  지정하지 않으면 Docker가 backend-net 쪽으로 포트를 게시해 방화벽 DNAT 규칙에 걸리지 않고 연결이 끊깁니다.
- 컨테이너를 새로 만들면 SSH 호스트 키가 바뀌므로 `ssh-keygen -R "[localhost]:2222"` 후 접속하세요.
- 포트 80이 이미 사용 중이면 `.env`의 `WEB_PORT`를 변경하세요.

## 브랜치 구성

| 브랜치 | 내용 |
|---|---|
| feat/docker_network | Docker 및 네트워크 구성 |
| feat/webserver | Nginx 웹서버와 보안 설정 |
| feat/firewall | iptables 방화벽 |
| feature/admin-access-control | 관리자 SSH 접근통제 |
| feat/integration | 통합 및 검증 |
