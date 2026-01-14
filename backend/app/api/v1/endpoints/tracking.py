from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from typing import List, Dict
import json

router = APIRouter()

class ConnectionManager:
    def __init__(self):
        # Map ride_id to list of connected websockets
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, websocket: WebSocket, ride_id: str):
        await websocket.accept()
        if ride_id not in self.active_connections:
            self.active_connections[ride_id] = []
        self.active_connections[ride_id].append(websocket)

    def disconnect(self, websocket: WebSocket, ride_id: str):
        if ride_id in self.active_connections:
            if websocket in self.active_connections[ride_id]:
                self.active_connections[ride_id].remove(websocket)
            if not self.active_connections[ride_id]:
                del self.active_connections[ride_id]

    async def broadcast(self, message: str, ride_id: str):
        if ride_id in self.active_connections:
            for connection in self.active_connections[ride_id]:
                await connection.send_text(message)

manager = ConnectionManager()

@router.websocket("/ws/location/{ride_id}")
async def websocket_endpoint(websocket: WebSocket, ride_id: str):
    await manager.connect(websocket, ride_id)
    try:
        while True:
            data = await websocket.receive_text()
            # Parse location data
            location_update = json.loads(data)
            
            # Here we could call Safety/ML service to check validation
            
            # Broadcast to all listeners in this ride (driver + passengers)
            await manager.broadcast(f"Location update for ride {ride_id}: {data}", ride_id)
            
    except WebSocketDisconnect:
        manager.disconnect(websocket, ride_id)
        # await manager.broadcast(f"Client left ride {ride_id}", ride_id)
