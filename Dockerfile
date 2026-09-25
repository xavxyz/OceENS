FROM python:3.12-slim
COPY --from=ghcr.io/astral-sh/uv:0.12.17 /uv /bin/
WORKDIR /app
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
# uv utilise le Python de l'image au lieu d'en télécharger un
ENV UV_PYTHON_DOWNLOADS=never UV_LINK_MODE=copy

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

# Dépendances d'abord, depuis le lockfile : cette couche reste en cache tant
# que pyproject.toml et uv.lock ne changent pas
COPY pyproject.toml uv.lock ./
RUN uv sync --locked --no-install-project

# Puis le paquet oceens lui-même (code, templates, static, import)
COPY README.md ./
COPY src src
RUN uv sync --locked

ENV PATH="/app/.venv/bin:$PATH"
# La racine du projet n'est pas un clone : le dossier de la base est explicite.
# Monter /app/database comme volume pour persister la base SQLite entre les redémarrages.
ENV LOCAL_DATABASE_DIR=/app/database

# Le fichier .env ne doit PAS être copié dans l'image : fournir les secrets via
# --env-file .env au lancement (docker run) ou via les variables d'environnement.

CMD ["oceens"]
