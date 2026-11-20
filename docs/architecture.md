# Docker 및 네트워크 구성 설계

## 1. Docker 컨테이너 구성

| 컨테이너 | 이미지 | 역할 |
|---|---|---|
| Firewall | alpine:3.20 | 외부 및 내부 네트워크 연결 |
| Webserver | nginx:alpine | 웹서비스 제공 |

현재는 네트워크 구성 및 통신 테스트를 위해 임시 이미지를 사용

## 2. 네트워크 구성

Docker Bridge 네트워크 2개를 생성

### 2.1 외부 네트워크 (edge-net)
- 네트워크 방식: Bridge
- 서브넷: 172.28.0.0/24
- Gateway: 172.28.0.1
- 연결 컨테이너: Firewall

### 2.2 내부 네트워크 (backend-net)
- 네트워크 방식: Bridge
- 서브넷: 172.29.0.0/24
- Gateway: 172.29.0.1
- 연결 컨테이너: Firewall, Webserver

## 3. 컨테이너 IP 주소

| 컨테이너 | 연결 네트워크 | IP 주소 |
|---|---|---|
| Firewall | edge-net | 172.28.0.2 |
| Firewall | backend-net | 172.29.0.2 |
| Webserver | backend-net | 172.29.0.10 |

Firewall은 두 네트워크에 모두 연결하고 Webserver는 내부 네트워크에만 연결

## 4. 포트 및 권한 설정

- 호스트의 8080번 포트를 Firewall 컨테이너의 80번 포트에 연결
- Webserver의 80번 포트는 호스트에 직접 공개하지 않음
- Firewall에 NET_ADMIN 권한 부여
- IP 포워딩 활성화 (net.ipv4.ip_forward = 1)

## 5. 테스트 및 검증 결과

| 테스트 항목 | 실행 결과 |
|---|---|
| Docker 컨테이너 실행 | Firewall, Webserver 모두 실행 성공 |
| 외부 네트워크 연결 | Firewall 연결 확인 |
| 내부 네트워크 연결 | Firewall, Webserver 연결 확인 |
| IP 포워딩 | 1 출력 확인 |
| Firewall 포트 | 127.0.0.1:8080 확인 |
| Webserver 포트 | 호스트 직접 공개 없음 |
| 컨테이너 간 HTTP 통신 | Nginx HTML 응답 확인 |

## 6. 추가 검증 및 구현 상태

### 6.1 IP 포워딩 확인
- 실행 명령어: `docker compose exec firewall sh -c "cat /proc/sys/net/ipv4/ip_forward"`
- 결과: `1`
- IP 패킷 전달 기능이 활성화된 것을 확인

### 6.2 포트 매핑 확인
- Firewall: `docker compose port firewall 80`
- 결과: `127.0.0.1:8080`
- Webserver: `docker compose port webserver 80`
- 결과: 호스트에 직접 공개된 포트 없음

현재 Firewall의 80번 포트는 로컬 테스트용으로 매핑되어 있으며, 실제 HTTP 요청을 처리하거나 Webserver로 전달하는 기능은 아직 구현되지 않음

### 6.3 내부 네트워크 HTTP 통신
- 실행 명령어: `docker compose exec firewall sh -c "wget -qO- http://webserver"`
- 결과: Nginx 기본 HTML 응답 수신 성공
- Firewall과 Webserver 사이의 내부 HTTP 통신을 확인



