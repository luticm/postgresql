# PostgreSQL Docker Examples

## Instructions

### 1. Start Docker Desktop

Make sure Docker Desktop is running.

### 2. Create the shared network

Run this once from the repository root:

```powershell
docker network create pgsharednet
```

If the network already exists, Docker reports an error that can be ignored.

### 3. Create a local Compose file

Each version includes a publishable `docker-compose-example.yml` template. Copy it to `docker-compose.yml` before using it:

```powershell
cd docker/pg18
Copy-Item docker-compose-example.yml docker-compose.yml
```

The copied `docker-compose.yml` is intentionally ignored by Git, so you can set local credentials, ports, and other settings without publishing them. The same pattern applies to `pg16`, `pg17`, and `pg19`.

Update `POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` in the local Compose file before connecting.

### 4. Start PostgreSQL

Run these commands from the selected version directory, for example `docker/pg18`:

```powershell
docker compose up --build
```

To run in the background:

```powershell
docker compose up --build -d
```

View logs:

```powershell
docker compose logs -f
```

Stop and remove the container without deleting the bind-mounted database files:

```powershell
docker compose down
```

The example ports are `54316` for pg16, `54317` for pg17, `54318` for pg18, and `54319` for pg19.

## Folder details

The Compose examples use bind mounts. The required host folders are:

```text
postgresql/
├── scripts/
└── docker/
    ├── pg16/
    │   └── fs/
    │       ├── data/
    │       └── scripts/
    ├── pg17/
    │   └── fs/
    │       ├── data/
    │       └── scripts/
    ├── pg18/
    │   └── fs/
    │       ├── data/
    │       └── scripts/
    └── pg19/
        └── fs/
            ├── data/
            └── scripts/
```

| Compose directory | Host path | Container path | Purpose |
| --- | --- | --- | --- |
| `docker/pg16` | `docker/pg16/fs/data` | `/var/lib/postgresql/data` | PostgreSQL 16 data directory |
| `docker/pg16` | `scripts` | `/home/scripts` | Shared host scripts |
| `docker/pg16` | `docker/pg16/fs/scripts` | `/home/dockerscripts` | PostgreSQL 16 container scripts |
| `docker/pg17` | `docker/pg17/fs/data` | `/var/lib/postgresql/data` | PostgreSQL 17 data directory |
| `docker/pg17` | `scripts` | `/home/scripts` | Shared host scripts |
| `docker/pg17` | `docker/pg17/fs/scripts` | `/home/dockerscripts` | PostgreSQL 17 container scripts |
| `docker/pg18` | `docker/pg18/fs/data` | `/var/lib/postgresql/18/docker` | PostgreSQL 18 data directory |
| `docker/pg18` | `scripts` | `/home/scripts` | Shared host scripts |
| `docker/pg18` | `docker/pg18/fs/scripts` | `/home/dockerscripts` | PostgreSQL 18 container scripts |
| `docker/pg19` | `docker/pg19/fs/data` | `/var/lib/postgresql/19/docker` | PostgreSQL 19 data directory |
| `docker/pg19` | `scripts` | `/home/scripts` | Shared host scripts |
| `docker/pg19` | `docker/pg19/fs/scripts` | `/home/dockerscripts` | PostgreSQL 19 container scripts |

Relative paths are resolved from the directory containing each Compose file. The `scripts` mount uses `..\\..\\scripts`, so it points to the repository-level `scripts` directory for every PostgreSQL version.

Keep each PostgreSQL version's `fs/data` directory separate. Do not reuse a data directory between major versions or populate it manually. Add shared scripts to `scripts` and version-specific helper scripts to that version's `fs/scripts` directory.