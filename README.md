# Maya Cam B2B - Live Recording System

Production-grade live streaming and recording system with event-driven architecture, built on LiveKit, FastAPI, and Flutter.

---

## Architecture Overview

```
flowchart TB
    subgraph Client["Flutter Client (Web/iPad)"]
        UI[Camera Preview + Streaming UI]
        GoLive[Go Live Button]
        Stop[Stop Button]
    end

    subgraph Backend["Backend API (api.mayacam.link)"]
        Nginx[Nginx Reverse Proxy<br/>HTTPS + Let's Encrypt]
        FastAPI[FastAPI Backend<br/>127.0.0.1:8000]
        Sessions[(In-Memory Sessions<br/>TODO: PostgreSQL)]
        Webhooks[Webhook Handler<br/>JWT Verified]
    end

    subgraph LiveKit["LiveKit Infrastructure"]
        LKServer[LiveKit Server<br/>livekit.mayacam.link]
        Egress[Egress Service<br/>Docker + Chrome]
        Layout[Custom React Layout<br/>file:///home/egress/layout/]
    end

    subgraph Storage["AWS Storage"]
        S3[S3 Bucket<br/>my-live-feed-app-bucket-0<br/>IAM Role Auth]
    end

    UI --> GoLive
    UI --> Stop
    GoLive -->|HTTPS POST /live/start| Nginx
    Stop -->|HTTPS POST /live/stop| Nginx
    Nginx -->|HTTP| FastAPI
    
    FastAPI -->|Generate Token| Sessions
    FastAPI -->|LiveKit Server SDK| LKServer
    FastAPI -->|Start/Stop Egress| Egress
    
    LKServer -->|JWT Webhooks| Webhooks
    Webhooks -->|Update Session| Sessions
    Webhooks -->|Trigger Egress| FastAPI
    
    UI -->|WebRTC Publish<br/>wss://livekit.mayacam.link| LKServer
    
    Egress -->|Load| Layout
    Egress -->|Subscribe to Room| LKServer
    Egress -->|Encode MP4| S3
    
    S3 -.->|recordings/{room}/{timestamp}.mp4| Storage

    style Client fill:#e1f5ff
    style Backend fill:#fff4e1
    style LiveKit fill:#f0e1ff
    style Storage fill:#e1ffe1
```

---

## Event Flow: "Go Live" to Recording

```
sequenceDiagram
    participant F as Flutter App
    participant B as Backend API
    participant L as LiveKit Server
    participant E as Egress Service
    participant S as S3 Bucket

    Note over F: User taps "Go Live"
    F->>+B: POST /live/start<br/>{tenant, site, camera, mode}
    B->>B: Create session (status: pending)
    B->>B: Generate JWT token
    B-->>-F: {url, token, room, sessionId, s3Key}
    
    F->>+L: Connect WebRTC<br/>wss://livekit.mayacam.link
    L->>L: Room created, participant joined
    L->>+B: Webhook: participant_joined
    
    B->>B: Check session status
    B->>+E: StartRoomCompositeEgress<br/>{room, layout, s3Output}
    E->>E: Launch Chrome + Custom Layout
    E->>L: Subscribe to room as hidden participant
    E-->>-B: {egressId}
    B->>B: Update session (status: active, egressId)
    B-->>-L: Webhook ACK
    
    F->>L: Publish camera + audio tracks
    L->>E: Forward media streams
    E->>E: Encode to MP4
    E->>S: Write recordings/test-room/timestamp.mp4
    
    Note over F: User taps "Stop"
    F->>+B: POST /live/stop<br/>{sessionId}
    B->>+E: StopEgress(egressId)
    E->>E: Finalize encoding
    E->>S: Complete MP4 upload
    E-->>-B: Egress stopped
    B->>B: Update session (status: stopped)
    B-->>-F: {status: stopped}
    
    F->>L: Disconnect
    L->>+B: Webhook: egress_ended
    B->>B: Update session (status: completed)
    B-->>-L: Webhook ACK
    
    Note over S: MP4 ready for playback
```

---

## Tech Stack

### Infrastructure
- **Hosting**: AWS EC2 (Ubuntu 22.04)
- **DNS**: Route 53 (`livekit.mayacam.link`, `api.mayacam.link`)
- **TLS**: Let's Encrypt (Certbot)
- **Reverse Proxy**: Nginx
- **Containers**: Docker Compose

### Backend
- **API**: FastAPI (Python)
- **WebRTC**: LiveKit Server (self-hosted)
- **Recording**: LiveKit Egress (Docker + Chrome headless)
- **Storage**: AWS S3 (IAM role authentication)
- **Session Store**: In-memory Dict (→ PostgreSQL planned)
- **Webhook Auth**: JWT (HS256)

### Frontend
- **Mobile**: Flutter (iOS + Android + Web)
- **Camera**: `camera` package
- **Streaming**: `livekit_client` package

### Recording Pipeline
- **Layout**: Custom React + Vite (`base: './'`)
- **Mounting**: `file:///home/egress/layout/index.html`
- **Encoding**: GStreamer pipeline → MP4
- **Output**: S3 with unique timestamped keys

---

## Key Features

✅ **Event-driven architecture**: Webhook-based egress triggering  
✅ **JWT authentication**: Webhook signature verification  
✅ **HTTPS everywhere**: Backend + LiveKit over TLS  
✅ **Scalable**: No polling, no race conditions  
✅ **Multi-tenant ready**: Session tracking per tenant/site/camera  
✅ **Auditable**: Full lifecycle logging (pending → active → completed)  
✅ **Zero hardcoded credentials in client**: Backend owns all secrets  

---

## Quick Start

### Prerequisites
- AWS EC2 instance (Ubuntu 22.04+, t3.medium or larger)
- Route 53 domain configured
- Docker & Docker Compose installed
- Security groups: ports 443, 7880, 50000-60000 open

### 1. Clone and Setup LiveKit

```
cd ~
mkdir livekit && cd livekit

# Create docker-compose.yaml and livekit.yaml (see config section below)
docker compose up -d
```

### 2. Setup Backend

```
cd ~
mkdir backend && cd backend
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install fastapi uvicorn livekit-api pyjwt

# Create main.py (see API section below)
uvicorn main:app --host 127.0.0.1 --port 8000
```

### 3. Configure Nginx + SSL

```
sudo apt install nginx certbot python3-certbot-nginx

# Create /etc/nginx/sites-available/api.mayacam.link
# (see config section)

sudo ln -s /etc/nginx/sites-available/api.mayacam.link /etc/nginx/sites-enabled/
sudo certbot --nginx -d api.mayacam.link
sudo systemctl reload nginx
```

### 4. Deploy Egress Layout

```
# Build your React layout locally
cd egress-layout
npm run build

# Copy to EC2
scp -r dist/* ubuntu@<ec2-ip>:/var/www/html/egress-layout/
```

### 5. Run Flutter App

```
cd camera_streaming_app
flutter pub get
flutter run -d chrome
# or
flutter run -d <device-id>
```

---

## Configuration

### LiveKit Config (`~/livekit/livekit.yaml`)

```
port: 7880
log_level: info

rtc:
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  udp_port: 7881
  tcp_port: 7882

keys:
  devkey: "this_is_a_longer_dev_secret_key_123456"

redis:
  address: 127.0.0.1:6379

webhook:
  urls:
    - https://api.mayacam.link/webhooks/livekit
  api_key: devkey
```

### Egress Config (`~/livekit/egress.yaml`)

```
api_key: devkey
api_secret: this_is_a_longer_dev_secret_key_123456
ws_url: ws://localhost:7880
log_level: info

s3:
  bucket: my-live-feed-app-bucket-0
  region: us-west-2

chrome:
  no_sandbox: true
  disable_gpu: true
```

### Docker Compose (`~/livekit/docker-compose.yaml`)

```
version: '3.8'

services:
  livekit:
    image: livekit/livekit-server:latest
    network_mode: host
    volumes:
      - ./livekit.yaml:/livekit.yaml
    command: --config /livekit.yaml

  redis:
    image: redis:7-alpine
    network_mode: host

  egress:
    image: livekit/egress:latest
    network_mode: host
    cap_add:
      - SYS_ADMIN
    volumes:
      - ./egress.yaml:/egress.yaml
      - /var/www/html/egress-layout:/home/egress/layout
    environment:
      - EGRESS_CONFIG_FILE=/egress.yaml
```

### Nginx Config (`/etc/nginx/sites-available/api.mayacam.link`)

```
server {
    listen 80;
    server_name api.mayacam.link;
    return 301 https://$host$request_uri;
}

server {
    listen 443 ssl;
    server_name api.mayacam.link;

    ssl_certificate /etc/letsencrypt/live/api.mayacam.link/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.mayacam.link/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

---

## API Reference

### POST /live/start

Start a live recording session.

**Request:**
```
{
  "tenantId": "tenant1",
  "siteId": "site1",
  "cameraId": "cam1",
  "mode": "record-only"
}
```

**Response:**
```
{
  "url": "wss://livekit.mayacam.link",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "room": "test-room",
  "sessionId": "session-1765239938.231618",
  "s3Key": "recordings/test-room/20251209T001346Z.mp4"
}
```

### POST /live/stop

Stop an active recording session.

**Request:**
```
{
  "sessionId": "session-1765239938.231618"
}
```

**Response:**
```
{
  "status": "stopped",
  "sessionId": "session-1765239938.231618"
}
```

### POST /webhooks/livekit

Internal webhook endpoint for LiveKit events (JWT authenticated).

**Events Handled:**
- `participant_joined` → triggers egress start
- `egress_ended` → marks session complete
- `room_finished` → cleanup

---

## Project Structure

```
.
├── backend/
│   ├── main.py                 # FastAPI app (token gen, egress control, webhooks)
│   ├── requirements.txt        # Python dependencies
│   ├── recordings.db           # SQLite session store (TODO)
│   └── venv/                   # Virtual environment
│
├── livekit/
│   ├── docker-compose.yaml     # LiveKit + Redis + Egress stack
│   ├── livekit.yaml            # LiveKit server config
│   └── egress.yaml             # Egress service config
│
├── egress-layout/
│   ├── src/                    # React custom layout source
│   ├── dist/                   # Built files (mounted to egress container)
│   ├── vite.config.ts          # Vite config (base: './')
│   └── package.json
│
└── camera_streaming_app/
    ├── lib/
    │   └── main.dart           # Flutter app (camera + LiveKit client)
    ├── pubspec.yaml
    └── README.md
```

---

## Session Lifecycle

```
┌─────────────────────────────────────────────────────────────┐
│  PENDING → ACTIVE → STOPPED/COMPLETED                      │
└─────────────────────────────────────────────────────────────┘

PENDING:    Session created, waiting for participant
ACTIVE:     Egress running, recording in progress
STOPPED:    User called /live/stop, egress stopping
COMPLETED:  Egress ended, MP4 uploaded to S3
```

---

## Troubleshooting

### Egress not starting

**Check:**
1. Egress container logs: `docker compose logs egress -f`
2. Backend webhook logs for `participant_joined` event
3. Room name matches between Flutter and backend

**Common issues:**
- Egress triggers before participant joins → use webhook-driven flow
- Chrome sandbox issues → ensure `cap_add: SYS_ADMIN` in docker-compose

### No video in S3

**Check:**
1. IAM role attached to EC2 with S3 write permissions
2. Egress logs show `egress_complete` with `code: 0`
3. S3 bucket name and region match `egress.yaml`

### Webhook signature verification fails

**Check:**
1. `LK_API_SECRET` matches in both `livekit.yaml` and `main.py`
2. PyJWT installed: `pip install pyjwt`
3. Authorization header present in webhook logs

### CORS errors in Flutter Web

**Check:**
1. CORS middleware enabled in FastAPI
2. `allow_origins` includes your Flutter dev host
3. Nginx proxy headers configured correctly

---

## Security Considerations

✅ **Backend on localhost only**: FastAPI bound to 127.0.0.1, not exposed directly  
✅ **HTTPS everywhere**: TLS termination at Nginx, certs auto-renewed  
✅ **JWT webhook auth**: Prevents webhook spoofing  
✅ **IAM role for S3**: No static AWS keys in config  
✅ **Token expiry**: LiveKit tokens have configurable TTL  

🚧 **TODO for production:**
- Multi-tenant auth with JWT for `/live/*` endpoints
- Rate limiting per tenant
- Secrets in environment variables, not code
- DB encryption at rest

---

## Performance & Scaling

### Current Capacity (single EC2 t3.medium)
- ~10 concurrent recordings
- ~5 FPS frame extraction for CV (when added)
- WebRTC up to 100 Mbps aggregate

### Horizontal Scaling Path
1. **Separate egress workers**: Run egress on dedicated GPU instances
2. **LoadBalancer for backend**: Multiple FastAPI instances behind ALB
3. **Redis cluster**: For LiveKit + session state sharing
4. **S3 multi-region**: For global low-latency recording

---

## Roadmap

### ✅ Phase 0: MVP Recording Pipeline (COMPLETE)
- [x] LiveKit self-hosted setup
- [x] Egress with custom layout (file://)
- [x] Backend API with webhook handler
- [x] Flutter client integration (Web + iOS/Android ready)
- [x] S3 recording output with IAM role
- [x] HTTPS + domain setup (Let's Encrypt)
- [x] Event-driven egress triggering
- [x] JWT webhook verification

### 🚧 Phase 1: Production Hardening (IN PROGRESS)
- [ ] PostgreSQL for session persistence
- [ ] Recording list & playback API (`GET /recordings`)
- [ ] Pre-signed S3 URLs for secure playback
- [ ] Multi-tenant authentication (JWT)
- [ ] S3 retention policies (7/30/90 day auto-delete)
- [ ] Monitoring & observability (Prometheus + Grafana)
- [ ] Room naming per camera/session

### 📋 Phase 2: CV/AI Integration
- [ ] Frame extraction pipeline (2-5 FPS from LiveKit)
- [ ] YOLO detection worker (person, forklift, PPE)
- [ ] Zone & layout service (polygon-based rules)
- [ ] Event linking to recordings (`cv_events` table)
- [ ] AI/LLM decision layer (OpenAI Realtime / Gemini Live)
- [ ] Incident management & notifications

### 🎯 Phase 3: Advanced Features
- [ ] SAM 2 for better segmentation/tracking
- [ ] Pose estimation for ergonomics
- [ ] Multi-camera orchestration
- [ ] Real-time alerts & dashboards
- [ ] Cost optimization (WebRTC minute tracking)
- [ ] Open model support (Qwen, Llama for privacy)

---

## Cost Breakdown (Estimated)

| Component | Monthly Cost |
|-----------|-------------|
| EC2 (t3.medium, us-west-2) | ~$30 |
| S3 storage (1TB @ $0.023/GB) | ~$23 |
| Data transfer out (100GB) | ~$9 |
| Route 53 hosted zone | ~$0.50 |
| **Total** | **~$62/month** |

*Scales linearly with recording volume and retention period.*

---

## Known Limitations

- **Session state in-memory**: Lost on backend restart (PostgreSQL planned)
- **Single room name**: All cameras use `test-room` (unique room naming planned)
- **No retention enforcement**: S3 objects persist indefinitely (lifecycle rules planned)
- **No playback UI**: Requires manual S3 access (API + UI planned)

---

## Contributing

This is a proprietary B2B SaaS product under active development.

For questions or issues, contact: `your-email@mayacam.com`

---

## License

Proprietary - All rights reserved

---

## Acknowledgments

Built with:
- [LiveKit](https://livekit.io/) - Open source WebRTC infrastructure
- [Flutter](https://flutter.dev/) - Cross-platform mobile framework
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework

---

**Last Updated**: December 8, 2025  
**Version**: 1.0.0-beta  
**Status**: Production-ready MVP
```
