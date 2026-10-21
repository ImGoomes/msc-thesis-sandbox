import os

import httpx
from fastapi import FastAPI, Request

from tracing import forward_headers

INVENTORY_URL = os.environ.get("INVENTORY_URL", "http://inventory:8000/stock")

app = FastAPI()


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/orders")
async def orders(request: Request):
    async with httpx.AsyncClient(timeout=10) as client:
        r = await client.get(INVENTORY_URL, headers=forward_headers(request))
    return {
        "service": "orders",
        "orders": [{"id": 1, "item": "widget", "qty": 2}],
        "inventory": r.json() if r.is_success else r.text,
        "status": r.status_code,
    }
