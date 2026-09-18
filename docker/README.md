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

The Compose examples use the same folder structure for every container version:

```text
postgresql/
├── scripts/
└── docker/
    └── pg<version>/
        └── fs/
            ├── data/
            └── scripts/
```

Replace `<version>` with `pg16`, `pg17`, `pg18`, or `pg19`. Each container uses the matching `fs/data` and `fs/scripts` folders for its version.

| Host path | Container path | Purpose |
| --- | --- | --- | --- |
| `docker/pg<version>/fs/data` | PostgreSQL data directory | Persisted database files |
| `scripts` | `/home/scripts` | Shared host scripts |
| `docker/pg<version>/fs/scripts` | `/home/dockerscripts` | Version-specific container scripts |

Relative paths are resolved from the directory containing each Compose file. The `scripts` mount uses `..\\..\\scripts`, so it points to the repository-level `scripts` directory for every PostgreSQL version.

PostgreSQL 16 and 17 mount the data directory at `/var/lib/postgresql/data`. PostgreSQL 18 and 19 mount it at their version-specific Docker data path.

Keep each PostgreSQL version's `fs/data` directory separate. Do not reuse a data directory between major versions or populate it manually. Add shared scripts to `scripts` and version-specific helper scripts to that version's `fs/scripts` directory.