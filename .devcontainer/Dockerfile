# Official Python 3.12 dev container image.
# Ships a non-root `vscode` user (UID 1000) and git already installed.
FROM mcr.microsoft.com/devcontainers/python:3.12

# sqlite3 CLI, so the database can be inspected directly from inside the container.
RUN apt-get update \
    && apt-get install -y --no-install-recommends sqlite3 \
    && rm -rf /var/lib/apt/lists/*

# Python dependencies are installed at BUILD time, not at runtime, so the
# container starts ready to work. Build context is the repo root.
COPY requirements.txt /tmp/requirements.txt
RUN pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt

# Run as non-root so files created in the container are not owned by root on the
# host. The repo is bind-mounted at /workspace, so the database and the Scryfall
# cache live in the mount and survive container rebuilds.
USER vscode
WORKDIR /workspace

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1
