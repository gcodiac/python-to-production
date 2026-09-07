# --- Stage 2, commit 5: multi-stage build ---------------------------------
#
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

WORKDIR /app

# The application itself is already inside the venv (it was `pip install`ed
# there in the builder stage above) - there is deliberately no second
# `COPY app ./app` here. Two copies of the same package on disk, relying on
# import order to pick the "right" one, is exactly the kind of confusing
# duplication this project doesn't want.
COPY --from=builder /opt/venv /opt/venv

ENV PATH="/opt/venv/bin:${PATH}"

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
