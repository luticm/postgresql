# PostgreSQL Learning Repository

This is a personal repository for learning, experimenting with, and exploring PostgreSQL. It starts with a Docker-based local environment and will grow with examples, notes, and exercises covering PostgreSQL features and administration.

## Folder structure

```text
postgresql/
├── docker/
│   ├── pg16/
│   ├── pg17/
│   ├── pg18/
│   ├── pg19/
│   └── README.md
├── scripts/
├── .gitignore
└── README.md
```

- `docker/`: PostgreSQL Docker Compose examples for each supported version.
- `scripts/`: Shared scripts used by the local containers.
- `README.md`: Repository overview and entry point for future learning topics.

As new PostgreSQL topics, examples, or exercises are added, their folders and purpose will be documented in this section.

## Prerequisites

- Docker Desktop
- Docker Compose v2

## Quick start

1. Start Docker Desktop.
2. Create the shared Docker network:

   ```powershell
   docker network create pgsharednet
   ```

3. Choose a PostgreSQL version and enter its directory. For example:

   ```powershell
   cd docker/pg18
   Copy-Item docker-compose-example.yml docker-compose.yml
   ```

4. Update the local Compose file with your credentials and settings.
5. Build and start PostgreSQL:

   ```powershell
   docker compose up --build -d
   ```

6. Follow the container logs when needed:

   ```powershell
   docker compose logs -f
   ```

Stop the selected container with:

```powershell
docker compose down
```

## Supported versions

| Version | Directory | Default port |
| --- | --- | ---: |
| PostgreSQL 16 | `docker/pg16` | `54316` |
| PostgreSQL 17 | `docker/pg17` | `54317` |
| PostgreSQL 18 | `docker/pg18` | `54318` |
| PostgreSQL 19 | `docker/pg19` | `54319` |

## Documentation

See [Docker instructions](docker/README.md) for Compose usage, volume dependencies, folder structure, local configuration, and container-specific notes.

## Local files

The `docker-compose-example.yml` files are safe-to-publish templates. Copy one to `docker-compose.yml` for local use. Active Compose files and PostgreSQL data directories are excluded by [.gitignore](.gitignore).
