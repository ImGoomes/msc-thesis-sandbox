import os

from fastapi import FastAPI

VERSION = os.environ.get("VERSION", "v1")

app = FastAPI()


@app.get("/healthz")
def healthz():
    return {"ok": True}


@app.get("/stock")
def stock():
    return {"service": "inventory", "version": VERSION, "stock": {"widget": 42 if VERSION == "v1" else 7}}
