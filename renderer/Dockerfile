FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ffmpeg \
        python3 \
        ca-certificates \
        fonts-dejavu \
        fonts-liberation \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY app/renderer.py /app/renderer.py

RUN mkdir -p /workspace/input /workspace/output /workspace/tmp

EXPOSE 8080

HEALTHCHECK --interval=10s --timeout=5s --retries=12 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8080/health', timeout=3)" || exit 1

ENTRYPOINT ["python3", "/app/renderer.py"]
