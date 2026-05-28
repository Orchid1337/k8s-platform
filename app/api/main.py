import logging
import os
import sys
import time

from fastapi import FastAPI, Request, Response
from prometheus_fastapi_instrumentator import Instrumentator
from pythonjsonlogger import jsonlogger

# config
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")
APP_NAME = os.getenv("APP_NAME", "k8s-platform-api")
LOG_LEVEL = os.getenv("LOG_LEVEL", "INFO").upper()
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")

# json logging so promtail can parse it
logger = logging.getLogger(APP_NAME)
logger.setLevel(LOG_LEVEL)

handler = logging.StreamHandler(sys.stdout)
formatter = jsonlogger.JsonFormatter(
    fmt="%(asctime)s %(name)s %(levelname)s %(message)s",
    rename_fields={"asctime": "timestamp", "levelname": "level"},
)
handler.setFormatter(formatter)
logger.handlers = [handler]

app = FastAPI(
    title=APP_NAME,
    version=APP_VERSION,
    description="Sample API for the k8s platform",
)

startup_time = time.time()
READY_AFTER_SECONDS = int(os.getenv("READY_AFTER_SECONDS", "2"))

# metrics — exclude health/ready so we don't pollute dashboards
instrumentator = Instrumentator(
    should_group_status_codes=True,
    should_ignore_untemplated=True,
    excluded_handlers=["/health", "/ready", "/metrics"],
)
instrumentator.instrument(app)


@app.on_event("startup")
async def startup_event():
    logger.info(
        "Application started",
        extra={"version": APP_VERSION, "environment": ENVIRONMENT},
    )


instrumentator.expose(app, endpoint="/metrics", include_in_schema=False)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start = time.time()
    response: Response = await call_next(request)
    duration_ms = round((time.time() - start) * 1000, 2)

    logger.info(
        "Request processed",
        extra={
            "method": request.method,
            "path": request.url.path,
            "status_code": response.status_code,
            "duration_ms": duration_ms,
            "client_ip": request.client.host if request.client else "unknown",
        },
    )
    return response


@app.get("/", tags=["root"])
async def root():
    return {
        "status": "ok",
        "version": APP_VERSION,
        "app": APP_NAME,
        "environment": ENVIRONMENT,
    }


@app.get("/health", tags=["probes"])
async def health():
    # NOTE: don't check dependencies here — only "is the process alive?"
    # checking deps in liveness = cascading restarts during outages
    return {"status": "healthy"}


@app.get("/ready", tags=["probes"])
async def ready():
    # grace period so k8s doesn't route traffic before we're actually ready
    elapsed = time.time() - startup_time
    if elapsed < READY_AFTER_SECONDS:
        return Response(
            content='{"status": "not_ready", "reason": "startup_grace_period"}',
            status_code=503,
            media_type="application/json",
        )
    return {"status": "ready", "uptime_seconds": round(elapsed, 1)}


@app.get("/info", tags=["info"])
async def info():
    return {
        "app": APP_NAME,
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "log_level": LOG_LEVEL,
        "python_version": sys.version,
    }
