# camera-streaming-app
Cross-platform AI camera streaming app
┌─────────────────────────────────────────────────────────────────────┐
│                        FLUTTER CLIENT (Web/iPad)                     │
│  - Camera preview + streaming UI                                    │
│  - "Go Live" / "Stop" buttons                                       │
└──────────────────┬──────────────────────────────────────────────────┘
                   │ HTTPS
                   │ POST /live/start
                   │ POST /live/stop
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    NGINX (api.mayacam.link:443)                      │
│  - Let's Encrypt TLS cert                                           │
│  - Reverse proxy to localhost:8000                                  │
└──────────────────┬──────────────────────────────────────────────────┘
                   │ HTTP
                   ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 FASTAPI BACKEND (127.0.0.1:8000)                     │
│  - Token generation (VideoGrants, JWT)                              │
│  - Session management (in-memory Dict)                              │
│  - Egress lifecycle control via LiveKit server SDK                  │
│  - Webhook handler (JWT-verified)                                   │
│                                                                      │
│  Endpoints:                                                          │
│  - POST /live/start → create session, return token                  │
│  - POST /live/stop → stop egress by sessionId                       │
│  - POST /webhooks/livekit → event-driven egress trigger             │
└──────┬───────────────────────────────┬───────────────────────────────┘
       │ LiveKit server SDK            │ Webhook receiver
       │ (ws://localhost:7880)         │ (JWT auth)
       ▼                               │
┌─────────────────────────────────────────────────────────────────────┐
│              LIVEKIT SERVER (livekit.mayacam.link)                   │
│  - WebRTC SFU (wss://livekit.mayacam.link)                          │
│  - Room management                                                   │
│  - Webhook sender (JWT-signed events)                               │
└──────┬───────────────────────────────┬───────────────────────────────┘
       │ WebRTC (publisher)            │ Egress API
       │                               ▼
       │                    ┌──────────────────────────────┐
       │                    │  LIVEKIT EGRESS (Docker)     │
       │                    │  - Chrome headless           │
       │                    │  - Custom layout (file://)   │
       │                    │  - GStreamer pipeline        │
       │                    └──────────┬───────────────────┘
       │                               │ MP4 encoding
       ▼                               ▼
┌────────────────────┐      ┌──────────────────────────────┐
│  FLUTTER CLIENT    │      │   AWS S3 (us-west-2)         │
│  - Publishes video │      │   my-live-feed-app-bucket-0  │
│  - Publishes audio │      │   recordings/test-room/*.mp4 │
└────────────────────┘      │   IAM role auth (no keys)    │
                            └──────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                        EVENT FLOW (Go Live)                          │
│                                                                      │
│  1. User taps "Go Live"                                             │
│  2. Flutter → POST /live/start                                      │
│  3. Backend: create session (status='pending'), generate token      │
│  4. Backend → return {url, token, room, sessionId}                  │
│  5. Flutter → connect to wss://livekit.mayacam.link with token      │
│  6. LiveKit: room created, participant joined                       │
│  7. LiveKit → webhook: participant_joined                           │
│  8. Backend webhook handler: start_room_recording()                 │
│  9. Egress: Chrome loads layout, START_RECORDING, pipeline playing  │
│ 10. S3: MP4 written with unique timestamped key                     │
│ 11. User taps "Stop" → Flutter calls /live/stop                     │
│ 12. Backend: stop_egress() → egress ends                            │
│ 13. LiveKit → webhook: egress_ended                                 │
│ 14. Backend: update session status='completed'                      │
└─────────────────────────────────────────────────────────────────────┘
