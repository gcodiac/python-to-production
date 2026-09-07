# --- Stage 2, commit 4: caching and layering -----------------------------
#
# Two changes from the naive first version:
#   1. An explicit, pinned base image tag instead of a moving one - see
#      container-learning/03-choosing-a-base-image.md.
#   2. Dependency metadata is copied and installed *before* application
#      source, so editing app/ code doesn't invalidate the (slow) dependency
#      install layer on every rebuild - see
#      container-learning/06-reproducible-python-dependencies.md and
#      container-learning/07-improving-the-dockerfile.md.
#
# python:3.12.14-slim-bookworm as of authoring time:
#   index digest sha256:782412e85d0f0984994c290652577d4018aff08145c85b262bb63dc0c7522254

FROM python:3.12.14-slim-bookworm

WORKDIR /app

# Dependency metadata only, so this layer is cached unless a dependency
# actually changes.
COPY pyproject.toml requirements.txt ./
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

# Application source changes far more often than dependencies do - copying
# it last means the expensive step above stays cached across source edits.
COPY app ./app
RUN pip install --no-cache-dir --no-deps .

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
