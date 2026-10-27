import os

import httpx
from fastapi import FastAPI, Request

from tracing import forward_headers

ORDERS_URL = os.environ.get("ORDERS_URL", "http://orders:8000/orders")

app = FastAPI()


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/")
async def index(request: Request):
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(ORDERS_URL, headers=forward_headers(request))
    return {"service": "frontend", "orders": r.json() if r.is_success else r.text, "status": r.status_code}
