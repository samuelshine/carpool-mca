---
phase: 4
plan: 1
wave: 1
---

# Plan 4.1: WebSocket Live Tracking

## Objective
Implement WebSocket endpoint for real-time ride tracking. Driver broadcasts GPS coordinates via WebSocket; connected passengers receive location updates in real time. Uses FastAPI's built-in WebSocket support — no additional dependencies.

## Context
- @.gsd/SPEC.md — REQ-17, REQ-18
- @.gsd/ROADMAP.md — Phase 4 deliverables
- @backend/app/routers/rides.py — Ride model and lifecycle endpoints
- @backend/app/core/deps.py — Auth dependencies
- @backend/app/core/security.py — JWT token verification

## Tasks

<task type="auto">
  <name>Create WebSocket connection manager</name>
  <files>backend/app/core/ws_manager.py</files>
  <action>
    Create a WebSocket connection manager that:
    1. Maintains a dict of `ride_id -> list of connected WebSockets`
    2. Methods:
       - `connect(ride_id, websocket)` — add to room
       - `disconnect(ride_id, websocket)` — remove from room
       - `broadcast(ride_id, data)` — send JSON to all connected clients in a ride room
    3. This is a singleton (module-level instance)
    
    ```python
    from fastapi import WebSocket
    from typing import Dict, List
    from uuid import UUID
    
    class ConnectionManager:
        def __init__(self):
            self.active_connections: Dict[str, List[WebSocket]] = {}
        
        async def connect(self, ride_id: str, websocket: WebSocket):
            await websocket.accept()
            if ride_id not in self.active_connections:
                self.active_connections[ride_id] = []
            self.active_connections[ride_id].append(websocket)
        
        async def disconnect(self, ride_id: str, websocket: WebSocket):
            if ride_id in self.active_connections:
                self.active_connections[ride_id].remove(websocket)
                if not self.active_connections[ride_id]:
                    del self.active_connections[ride_id]
        
        async def broadcast(self, ride_id: str, data: dict):
            if ride_id in self.active_connections:
                for ws in self.active_connections[ride_id]:
                    try:
                        await ws.send_json(data)
                    except:
                        pass  # dead connections cleaned up on disconnect
    
    manager = ConnectionManager()
    ```
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from core.ws_manager import manager, ConnectionManager
    assert isinstance(manager, ConnectionManager)
    print('ConnectionManager OK')
    "
  </verify>
  <done>`ConnectionManager` importable with `connect`, `disconnect`, `broadcast` methods</done>
</task>

<task type="auto">
  <name>Create WebSocket tracking endpoint</name>
  <files>backend/app/routers/tracking.py, backend/app/main.py</files>
  <action>
    Create a tracking router with WebSocket endpoint:

    ```python
    # routers/tracking.py
    from fastapi import APIRouter, WebSocket, WebSocketDisconnect, Query
    from core.ws_manager import manager
    from core.security import verify_token  # JWT verification
    
    router = APIRouter(tags=["Tracking"])
    
    @router.websocket("/ws/rides/{ride_id}/track")
    async def track_ride(websocket: WebSocket, ride_id: str, token: str = Query(...)):
    ```

    Flow:
    1. Client connects with `ws://host/ws/rides/{ride_id}/track?token=JWT`
    2. Verify JWT token from query parameter (WebSockets can't use headers easily)
    3. If invalid → close with code 4001
    4. Add to ride room via manager.connect()
    5. Listen for messages:
       - If message has `type: "location_update"` with `lat`, `lng` → broadcast to room
       - Echo acknowledgment back to sender
    6. On disconnect → manager.disconnect()

    Register in main.py:
    ```python
    from routers import tracking as tracking_router
    app.include_router(tracking_router.router)
    ```

    WebSocket auth helper (add to security.py or inline in tracking.py):
    - Extract user_id from JWT
    - No need for full DB lookup — just validate token is valid
    - If token is expired or invalid, close WebSocket with appropriate code
  </action>
  <verify>
    cd backend/app && source ../venv/bin/activate && python3 -c "
    from main import app
    ws_routes = [r.path for r in app.routes if hasattr(r, 'path') and 'ws' in r.path]
    assert '/ws/rides/{ride_id}/track' in ws_routes, f'Missing WS route, got: {ws_routes}'
    print('WebSocket route OK')
    "
  </verify>
  <done>WebSocket endpoint at `/ws/rides/{ride_id}/track` registered, authenticates via query token</done>
</task>

## Success Criteria
- [ ] `ConnectionManager` class manages per-ride WebSocket rooms
- [ ] `ws://host/ws/rides/{ride_id}/track?token=JWT` endpoint registered
- [ ] JWT auth on WebSocket connection (close 4001 if invalid)
- [ ] Driver sends location → broadcast to all room members
- [ ] Server starts clean with WebSocket route
