"""Forward the headers Envoy needs to stitch spans into one trace."""

from fastapi import Request

TRACE_HEADERS = (
    "x-request-id",
    "traceparent",
    "tracestate",
    "x-b3-traceid",
    "x-b3-spanid",
    "x-b3-parentspanid",
    "x-b3-sampled",
    "x-b3-flags",
    "b3",
)


def forward_headers(request: Request) -> dict[str, str]:
    return {h: request.headers[h] for h in TRACE_HEADERS if h in request.headers}
