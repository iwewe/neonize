#!/usr/bin/env python3
"""
Neonize n8n Bridge API
======================

FastAPI server sebagai bridge antara Neonize dan n8n.
Menyediakan REST API untuk n8n memanggil fungsi Neonize,
dan webhook untuk forward events dari Neonize ke n8n.

Features:
- REST API endpoints untuk send message, broadcast, group management
- Webhook untuk forward Neonize events ke n8n
- Health check & monitoring
- Request validation dengan Pydantic
- Error handling & logging

Installation:
    pip install fastapi uvicorn httpx pydantic

Usage:
    uvicorn n8n_bridge:app --host 0.0.0.0 --port 8000

Author: Neonize Team
License: Apache 2.0
"""

from fastapi import FastAPI, HTTPException, BackgroundTasks, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, validator
from typing import Optional, List
from datetime import datetime
import httpx
import asyncio
import threading
import logging
import os

from neonize.client import NewClient
from neonize.events import MessageEv, ConnectedEv, DisconnectedEv, ReceiptEv
from neonize.utils import build_jid

# ==================== CONFIGURATION ====================

# n8n webhook URL (set via env variable)
N8N_WEBHOOK_URL = os.getenv("N8N_WEBHOOK_URL", "http://localhost:5678/webhook/emergency")

# API Key untuk security (optional)
API_KEY = os.getenv("API_KEY", "your-secret-api-key")

# Neonize session
SESSION_NAME = os.getenv("SESSION_NAME", "n8n_bridge")

# ==================== LOGGING ====================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# ==================== PYDANTIC MODELS ====================

class SendMessageRequest(BaseModel):
    """Request model untuk send message"""
    phone: str
    message: str
    quote_message_id: Optional[str] = None

    @validator('phone')
    def validate_phone(cls, v):
        # Remove non-digits
        phone_clean = ''.join(filter(str.isdigit, v))

        # Must start with 62 (Indonesia)
        if not phone_clean.startswith('62'):
            raise ValueError('Phone must start with 62 (Indonesian number)')

        if len(phone_clean) < 10 or len(phone_clean) > 15:
            raise ValueError('Invalid phone number length')

        return phone_clean

    @validator('message')
    def validate_message(cls, v):
        if not v.strip():
            raise ValueError('Message cannot be empty')
        if len(v) > 5000:
            raise ValueError('Message too long (max 5000 chars)')
        return v


class SendImageRequest(BaseModel):
    """Request model untuk send image"""
    phone: str
    image_url: str
    caption: Optional[str] = None

    @validator('image_url')
    def validate_url(cls, v):
        if not v.startswith(('http://', 'https://')):
            raise ValueError('Invalid image URL')
        return v


class SendBroadcastRequest(BaseModel):
    """Request model untuk broadcast"""
    phones: List[str]
    message: str

    @validator('phones')
    def validate_phones(cls, v):
        if len(v) == 0:
            raise ValueError('At least one phone number required')
        if len(v) > 100:
            raise ValueError('Max 100 recipients per broadcast')
        return v


class CreateGroupRequest(BaseModel):
    """Request model untuk create group"""
    name: str
    members: List[str]

    @validator('name')
    def validate_name(cls, v):
        if len(v) < 3 or len(v) > 50:
            raise ValueError('Group name must be 3-50 characters')
        return v

    @validator('members')
    def validate_members(cls, v):
        if len(v) < 1:
            raise ValueError('At least 1 member required')
        if len(v) > 100:
            raise ValueError('Max 100 members')
        return v


class CheckWhatsAppRequest(BaseModel):
    """Request model untuk check if number is on WhatsApp"""
    phones: List[str]


# ==================== RESPONSE MODELS ====================

class ApiResponse(BaseModel):
    """Standard API response"""
    success: bool
    message: str
    data: Optional[dict] = None


# ==================== FASTAPI APP ====================

app = FastAPI(
    title="Neonize n8n Bridge",
    description="REST API bridge between Neonize and n8n for emergency response",
    version="1.0.0"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ==================== GLOBAL STATE ====================

neonize_client: Optional[NewClient] = None
client_connected = False

# ==================== AUTHENTICATION ====================

async def verify_api_key(x_api_key: str = Header(...)):
    """Verify API key dari header"""
    if x_api_key != API_KEY:
        raise HTTPException(status_code=401, detail="Invalid API Key")
    return x_api_key


# ==================== NEONIZE SETUP ====================

def setup_neonize_client():
    """Initialize dan setup Neonize client"""
    global neonize_client, client_connected

    logger.info("Initializing Neonize client...")

    # Create sessions directory if it doesn't exist
    os.makedirs("sessions", exist_ok=True)

    # Store database in sessions directory for persistence
    database_path = f"sessions/{SESSION_NAME}.db"
    logger.info(f"Using database: {database_path}")

    neonize_client = NewClient(database_path)

    # Setup event handlers
    @neonize_client.event
    def on_connected(client: NewClient, event: ConnectedEv):
        global client_connected
        client_connected = True
        logger.info("✅ Neonize connected to WhatsApp!")

        # Notify n8n bahwa bot online
        asyncio.run(forward_to_n8n("bot_connected", {
            "timestamp": datetime.now().isoformat(),
            "session": SESSION_NAME
        }))

    @neonize_client.event
    def on_disconnected(client: NewClient, event: DisconnectedEv):
        global client_connected
        client_connected = False
        logger.warning("⚠️ Neonize disconnected!")

        asyncio.run(forward_to_n8n("bot_disconnected", {
            "timestamp": datetime.now().isoformat()
        }))

    @neonize_client.event
    def on_message(client: NewClient, event: MessageEv):
        """Forward incoming messages ke n8n"""

        # Skip our own messages
        if event.Info.MessageSource.IsFromMe:
            return

        # Extract data
        sender = event.Info.MessageSource.Sender
        chat = event.Info.MessageSource.Chat
        message_id = event.Info.ID
        timestamp = event.Info.Timestamp
        push_name = event.Info.PushName or "Unknown"
        is_group = event.Info.MessageSource.IsGroup

        msg = event.Message

        # Parse message content
        message_data = {
            "event_id": f"msg_{message_id}",
            "message_id": message_id,
            "sender": sender,
            "sender_name": push_name,
            "chat": chat,
            "is_group": is_group,
            "timestamp": timestamp,
            "text": None,
            "media_type": None,
            "location": None
        }

        # Extract content based on type
        if msg.conversation:
            message_data["text"] = msg.conversation
            message_data["media_type"] = "text"

        elif msg.extendedTextMessage:
            message_data["text"] = msg.extendedTextMessage.text
            message_data["media_type"] = "text"

        elif msg.imageMessage:
            message_data["media_type"] = "image"
            message_data["caption"] = msg.imageMessage.caption

        elif msg.videoMessage:
            message_data["media_type"] = "video"
            message_data["caption"] = msg.videoMessage.caption

        elif msg.locationMessage:
            message_data["media_type"] = "location"
            message_data["location"] = {
                "latitude": msg.locationMessage.degreesLatitude,
                "longitude": msg.locationMessage.degreesLongitude
            }

        elif msg.documentMessage:
            message_data["media_type"] = "document"
            message_data["filename"] = msg.documentMessage.filename

        # Forward ke n8n
        asyncio.run(forward_to_n8n("message_received", message_data))

        logger.info(f"Message forwarded to n8n: {message_id}")

    @neonize_client.event
    def on_receipt(client: NewClient, event: ReceiptEv):
        """Forward message receipts ke n8n"""
        asyncio.run(forward_to_n8n("receipt", {
            "type": str(event.Type),
            "message_ids": event.MessageIDs,
            "timestamp": datetime.now().isoformat(),
            "sender": event.MessageSource.Sender if event.MessageSource else None
        }))

    # Connect dalam background thread
    logger.info("Starting Neonize connection thread...")
    thread = threading.Thread(target=neonize_client.connect, daemon=True)
    thread.start()


async def forward_to_n8n(event_type: str, data: dict):
    """Forward events ke n8n webhook"""
    payload = {
        "event_type": event_type,
        "timestamp": datetime.now().isoformat(),
        "data": data
    }

    try:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                N8N_WEBHOOK_URL,
                json=payload,
                timeout=10.0
            )

            if response.status_code != 200:
                logger.warning(f"n8n webhook returned {response.status_code}")

    except httpx.RequestError as e:
        logger.error(f"Failed to forward to n8n: {e}")
    except Exception as e:
        logger.error(f"Unexpected error forwarding to n8n: {e}")


# ==================== STARTUP & SHUTDOWN ====================

@app.on_event("startup")
async def startup_event():
    """App startup - initialize Neonize"""
    logger.info("🚀 Starting Neonize n8n Bridge...")
    setup_neonize_client()


@app.on_event("shutdown")
async def shutdown_event():
    """App shutdown - cleanup"""
    global neonize_client
    logger.info("👋 Shutting down...")

    if neonize_client:
        try:
            neonize_client.disconnect()
        except:
            pass


# ==================== HEALTH CHECK ====================

@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy" if client_connected else "disconnected",
        "neonize_connected": client_connected,
        "timestamp": datetime.now().isoformat(),
        "session": SESSION_NAME
    }


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "Neonize n8n Bridge",
        "version": "1.0.0",
        "status": "running",
        "docs": "/docs"
    }


# ==================== WHATSAPP OPERATIONS ====================

@app.post("/send-message", response_model=ApiResponse)
async def send_message(
    request: SendMessageRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Send WhatsApp message

    Example n8n HTTP Request Node:
    ```
    POST http://localhost:8000/send-message
    Headers: {"X-Api-Key": "your-secret-api-key"}
    Body: {
        "phone": "628123456789",
        "message": "Hello from n8n!"
    }
    ```
    """
    if not client_connected:
        raise HTTPException(status_code=503, detail="WhatsApp not connected")

    try:
        jid = build_jid(request.phone)

        # Send message
        neonize_client.send_message(jid, text=request.message)

        logger.info(f"Message sent to {request.phone}")

        return ApiResponse(
            success=True,
            message="Message sent successfully",
            data={
                "phone": request.phone,
                "jid": jid,
                "timestamp": datetime.now().isoformat()
            }
        )

    except Exception as e:
        logger.error(f"Failed to send message: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-image", response_model=ApiResponse)
async def send_image(
    request: SendImageRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Send image with caption

    Example:
    ```
    POST /send-image
    {
        "phone": "628123456789",
        "image_url": "https://example.com/image.jpg",
        "caption": "Check this out!"
    }
    ```
    """
    if not client_connected:
        raise HTTPException(status_code=503, detail="WhatsApp not connected")

    try:
        jid = build_jid(request.phone)

        # Download image
        async with httpx.AsyncClient() as client:
            response = await client.get(request.image_url, timeout=30.0)
            image_data = response.content

        # Send image
        neonize_client.send_image(
            jid,
            image=image_data,
            caption=request.caption
        )

        logger.info(f"Image sent to {request.phone}")

        return ApiResponse(
            success=True,
            message="Image sent successfully",
            data={"phone": request.phone}
        )

    except httpx.RequestError as e:
        raise HTTPException(status_code=400, detail=f"Failed to download image: {e}")
    except Exception as e:
        logger.error(f"Failed to send image: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/send-broadcast", response_model=ApiResponse)
async def send_broadcast(
    request: SendBroadcastRequest,
    background_tasks: BackgroundTasks,
    api_key: str = Depends(verify_api_key)
):
    """
    Broadcast message ke multiple numbers

    Example:
    ```
    POST /send-broadcast
    {
        "phones": ["628123456789", "628987654321"],
        "message": "Emergency alert!"
    }
    ```
    """
    if not client_connected:
        raise HTTPException(status_code=503, detail="WhatsApp not connected")

    def _send_broadcast():
        """Background task untuk kirim broadcast"""
        results = []
        for phone in request.phones:
            try:
                jid = build_jid(phone)
                neonize_client.send_message(jid, text=request.message)
                results.append({"phone": phone, "status": "sent"})
                logger.info(f"Broadcast sent to {phone}")
            except Exception as e:
                results.append({"phone": phone, "status": "failed", "error": str(e)})
                logger.error(f"Broadcast failed for {phone}: {e}")

        # Forward results ke n8n
        asyncio.run(forward_to_n8n("broadcast_completed", {
            "results": results,
            "total": len(request.phones),
            "sent": sum(1 for r in results if r['status'] == 'sent'),
            "failed": sum(1 for r in results if r['status'] == 'failed')
        }))

    # Run di background
    background_tasks.add_task(_send_broadcast)

    return ApiResponse(
        success=True,
        message=f"Broadcast queued for {len(request.phones)} recipients",
        data={"recipient_count": len(request.phones)}
    )


@app.post("/create-group", response_model=ApiResponse)
async def create_group(
    request: CreateGroupRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Create WhatsApp group

    Example:
    ```
    POST /create-group
    {
        "name": "Emergency Response Team",
        "members": ["628123456789", "628987654321"]
    }
    ```
    """
    if not client_connected:
        raise HTTPException(status_code=503, detail="WhatsApp not connected")

    try:
        # Convert ke JIDs
        member_jids = [build_jid(phone) for phone in request.members]

        # Create group
        group_info = neonize_client.create_group(
            name=request.name,
            participants=member_jids
        )

        logger.info(f"Group created: {group_info.JID}")

        return ApiResponse(
            success=True,
            message="Group created successfully",
            data={
                "group_jid": group_info.JID,
                "group_name": group_info.Name,
                "member_count": len(request.members)
            }
        )

    except Exception as e:
        logger.error(f"Failed to create group: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/check-whatsapp", response_model=ApiResponse)
async def check_whatsapp(
    request: CheckWhatsAppRequest,
    api_key: str = Depends(verify_api_key)
):
    """
    Check if phone numbers are on WhatsApp

    Example:
    ```
    POST /check-whatsapp
    {
        "phones": ["628123456789", "628987654321"]
    }
    ```
    """
    if not client_connected:
        raise HTTPException(status_code=503, detail="WhatsApp not connected")

    try:
        results = []
        for phone in request.phones:
            try:
                check_results = neonize_client.is_on_whatsapp(phone)
                is_registered = len(check_results) > 0 and check_results[0].IsIn

                results.append({
                    "phone": phone,
                    "is_on_whatsapp": is_registered,
                    "jid": check_results[0].JID if check_results else None
                })
            except Exception as e:
                results.append({
                    "phone": phone,
                    "is_on_whatsapp": False,
                    "error": str(e)
                })

        return ApiResponse(
            success=True,
            message=f"Checked {len(request.phones)} numbers",
            data={"results": results}
        )

    except Exception as e:
        logger.error(f"Failed to check WhatsApp: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# ==================== ADMIN ENDPOINTS ====================

@app.get("/status", response_model=ApiResponse)
async def get_status(api_key: str = Depends(verify_api_key)):
    """Get bot status & info"""
    if not neonize_client:
        return ApiResponse(
            success=False,
            message="Client not initialized"
        )

    try:
        is_connected = neonize_client.is_connected()
        is_logged_in = neonize_client.is_logged_in()

        return ApiResponse(
            success=True,
            message="Status retrieved",
            data={
                "connected": is_connected,
                "logged_in": is_logged_in,
                "session": SESSION_NAME,
                "n8n_webhook": N8N_WEBHOOK_URL
            }
        )

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ==================== ERROR HANDLERS ====================

@app.exception_handler(HTTPException)
async def http_exception_handler(request, exc):
    """Custom HTTP exception handler"""
    return {
        "success": False,
        "message": exc.detail,
        "status_code": exc.status_code
    }


# ==================== MAIN ====================

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "n8n_bridge:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info"
    )
