# --- Stage 2, commit 1: the naive first version ---------------------------
#
# This is deliberately the simplest Dockerfile that actually works. It has
# real problems (runs as root, rebuilds dependencies on every source change,
# copies more than it needs to) that later commits on this branch fix one at
# a time - see container-learning/04-building-the-first-image.md.

FROM python:3.12-slim

WORKDIR /app

COPY . .

RUN pip install --no-cache-dir .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
