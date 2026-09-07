# This app's dependencies (fastapi, uvicorn[standard], python-dotenv) all
# ship prebuilt wheels for this platform - nothing here actually needs a
# compiler, so multi-stage isn't "required" the way it is for projects with
# C-extension dependencies. It still earns its place for two reasons:
#   1. The final image never contains pip/setuptools/wheel at all (they're
#      removed from the venv before it's copied into the runtime stage), so
#      there is no package installer available at runtime - real
#      attack-surface reduction, not cosmetic.
#   2. It cleanly separates "what it took to build this" from "what it takes
#      to run this," which pays off the moment this app ever *does* gain a
#      compiled dependency.
# See container-learning/07-improving-the-dockerfile.md for the full
# reasoning, including when multi-stage would NOT be worth the complexity.
#
# python:3.12.14-slim-bookworm as of authoring time:
#   index digest sha256:782412e85d0f0984994c290652577d4018aff08145c85b262bb63dc0c7522254

FROM python:3.12.14-slim-bookworm AS builder

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:${PATH}"

COPY pyproject.toml requirements.txt ./
RUN pip install --no-cache-dir --require-hashes -r requirements.txt

COPY app ./app
RUN pip install --no-cache-dir --no-deps . \
    && pip uninstall --yes pip setuptools wheel


FROM python:3.12.14-slim-bookworm

# OCI image metadata - see container-learning/24-oci-image-metadata-and-the-software-supply-chain.md.
# GIT_REVISION is a build ARG, not a LABEL baked in statically, because it's
# only known at build time: docker build --build-arg GIT_REVISION=$(git rev-parse --short HEAD) ...
# No org.opencontainers.image.source label - that would need a real,
# public repository URL, and this project doesn't have one to publish yet.
ARG GIT_REVISION=unknown
LABEL org.opencontainers.image.title="notes-app" \
      org.opencontainers.image.description="A minimal Notes API built with FastAPI and SQLite." \
      org.opencontainers.image.version="0.1.0" \
      org.opencontainers.image.revision="${GIT_REVISION}"

# A dedicated, unprivileged user for the application to run as - see
# container-learning/08-running-as-non-root.md. Container root isn't the
# same thing as host root, but running as a named, uid-1000 user is still
# real defence in depth: it limits what an attacker who gains code
# execution inside the container can do to the container's own filesystem.
RUN groupadd --gid 1000 appuser \
    && useradd --uid 1000 --gid appuser --no-create-home --shell /usr/sbin/nologin appuser

WORKDIR /app

# The application itself is already inside the venv (it was `pip install`ed
# there in the builder stage above) - there is deliberately no second
# `COPY app ./app` here. Two copies of the same package on disk, relying on
# import order to pick the "right" one, is exactly the kind of confusing
# duplication this project doesn't want.
COPY --from=builder /opt/venv /opt/venv

# appuser only needs to read the venv, but needs to be able to write to its
# own working directory - the zero-configuration default (no DATABASE_URL
# set) resolves to a relative "./notes.db" path under here.
RUN chown -R appuser:appuser /app

# A container's own writable layer is thrown away with the container - see
# container-learning/10-persistent-data-and-sqlite.md. /data is this
# image's documented, explicit location for anything that must survive a
# container being replaced. The image only prepares the directory and its
# ownership; it deliberately does NOT set DATABASE_URL itself (that would
# be baking an environment-specific value into the image) - whoever runs
# this image decides whether /data is a named volume, a bind mount, or left
# as ordinary (non-persistent) container storage.
RUN mkdir -p /data && chown appuser:appuser /data
VOLUME ["/data"]

# PYTHONDONTWRITEBYTECODE: don't write .pyc files into /opt/venv at
# runtime - harmless either way, but pointless work once the root
# filesystem is read-only (see compose.yaml), and keeps the image's
# contents exactly what was built, nothing added at first import.
# PYTHONUNBUFFERED: flush stdout/stderr immediately rather than buffering,
# so `docker logs` shows output as it happens instead of in delayed chunks.
ENV PATH="/opt/venv/bin:${PATH}" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Numeric form, not the name - a name requires /etc/passwd to be present
# and readable to resolve, which not every minimal base image guarantees.
USER 1000:1000

EXPOSE 8000

# Uses the Stage 1 /health endpoint - see
# container-learning/11-health-signals-and-container-lifecycle.md. No curl
# in this image (adding it just for a health probe would be its own
# needless attack surface); Python is already here, so it does the HTTP
# GET directly. A non-2xx response or connection failure raises, which
# gives this a non-zero exit code - exactly what Docker expects.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD ["python", "-c", "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health', timeout=2)"]

# Exec form (a JSON array, not a bare string) - see
# container-learning/15-signals-and-graceful-shutdown.md. Shell-form CMD
# would run as a child of /bin/sh -c, which becomes PID 1 instead of
# uvicorn, and `docker stop`'s SIGTERM would hit the shell rather than the
# process that actually needs to shut down gracefully.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
