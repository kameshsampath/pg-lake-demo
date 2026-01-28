# pg_lake Demo

A hands-on demo showcasing [pg_lake](https://github.com/Snowflake-Labs/pg_lake) capabilities: reading Parquet files directly from S3, automatic schema inference, and upgrading to fully managed Iceberg tables with ACID support.

## Overview

This demo uses the Palmer Penguins dataset to demonstrate:

1. **Zero-schema Parquet scanning** - Create foreign tables that automatically infer schema from Parquet files
2. **Iceberg table creation** - Promote raw Parquet files to managed Iceberg tables
3. **ACID operations** - Perform DELETE operations on lake data with full transactional support

## Prerequisites

### System Requirements

- Docker Desktop with 8GB+ RAM allocated (16GB recommended for building images)
- macOS, Linux, or Windows with WSL2

### Required Tools

#### Docker

Docker Desktop is required to run pg_lake and LocalStack containers.

```bash
# macOS
brew install --cask docker

# Linux - follow https://docs.docker.com/engine/install/

# Verify installation
docker --version
docker compose version
```

> **Important**: Allocate at least 8GB RAM to Docker (16GB recommended).
> Docker Desktop → Settings → Resources → Memory

#### Git

```bash
# macOS
brew install git

# Linux (Debian/Ubuntu)
sudo apt install git

# Verify installation
git --version
```

#### curl

Usually pre-installed on macOS and Linux. Used for downloading files and health checks.

```bash
# Verify installation
curl --version
```

#### gettext (for envsubst)

Provides `envsubst` for environment variable substitution in SQL templates.

```bash
# macOS
brew install gettext

# Linux (Debian/Ubuntu) - usually pre-installed
sudo apt install gettext

# Verify installation
envsubst --version
```

#### Task Runner (go-task)

```bash
# macOS
brew install go-task

# Linux
sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

# Verify installation
task --version
```

#### Python and uv

Python 3.12+ is required. We use `uv` for fast dependency management.

```bash
# Install uv (Python package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# Verify installation
uv --version
```

### Optional Tools

#### psql (PostgreSQL Client)

For interactive SQL sessions. The demo tasks use `docker exec` so this is optional.

```bash
# macOS
brew install libpq
brew link --force libpq

# Linux (Debian/Ubuntu)
sudo apt install postgresql-client

# Verify installation
psql --version
```

#### direnv (Optional)

Automatically loads environment variables when entering the project directory. Not required - the Taskfile loads `.env` automatically.

```bash
# macOS
brew install direnv

# Linux (Debian/Ubuntu)
sudo apt install direnv

# Add to your shell (~/.zshrc or ~/.bashrc)
eval "$(direnv hook zsh)"  # or bash
```

> **Note**: If not using direnv, run `source .env` before using direct shell commands (e.g., `psql`, `aws`). Taskfile commands work without this.

### Build and Start pg_lake

This demo requires the pg_lake Docker images. You have two options:

#### Option A: Integrated (Recommended)

This demo can clone and manage pg_lake for you using sparse checkout (only the `docker/` folder):

```bash
# Clone pg_lake and start services (first run builds images ~10-15 min)
task pg_lake:up
```

#### Option B: Manual

If you prefer to manage pg_lake separately, follow the [pg_lake Local Development Guide](https://github.com/Snowflake-Labs/pg_lake/blob/main/docker/LOCAL_DEV.md):

```bash
# Clone pg_lake repository
git clone https://github.com/Snowflake-Labs/pg_lake.git
cd pg_lake/docker

# Build and start services (PostgreSQL 18 + LocalStack)
task compose:up PG_MAJOR=18
```

#### Services Started

- `pg_lake-postgres` - PostgreSQL 18 with pg_lake extensions (port 5432)
- `pgduck-server` - DuckDB integration for query execution
- `localstack` - S3-compatible storage (port 4566)

## Quick Start

```bash
# 1. Clone this repository
git clone <this-repo>
cd pg-lake-demo

# 2. Set up environment (creates .env, .aws/, syncs Python deps)
task setup:all

# 3. Start pg_lake (clones and builds on first run ~10-15 min)
task pg_lake:up

# 4. Verify services are running
task check:all

# 5. Upload sample data to LocalStack S3
task s3:upload

# 6. Run the demo steps (see Demo Walkthrough below)
task demo:init           # Enable pg_lake extension
task demo:secret         # Create S3 credentials
task demo:foreign-table  # Query Parquet with zero schema
task demo:iceberg        # Upgrade to Iceberg table
task demo:modify         # ACID DELETE operation
```

> **Note**: All `task` commands automatically load `.env`. For direct shell commands (e.g., `psql`, `aws`), run `source .env` first, or use `direnv allow` if you have direnv installed.

## Demo Walkthrough

### Step 1: Initialize pg_lake Extension

```bash
task demo:init
```

This enables the `pg_lake` extension in PostgreSQL:

```sql
CREATE EXTENSION IF NOT EXISTS pg_lake CASCADE;
```

### Step 2: Scan Raw Parquet (Zero Schema)

```bash
task demo:foreign-table
```

Creates a foreign table that automatically infers the schema from the Parquet file:

```sql
CREATE FOREIGN TABLE penguins_raw() 
SERVER pg_lake 
OPTIONS (path 's3://wildlife/raw/penguins.parquet');

SELECT * FROM penguins_raw LIMIT 5;
```

> **Note**: The empty `()` triggers automatic schema inference - no need to define columns!

### Step 3: Upgrade to Iceberg Table

```bash
task demo:iceberg
```

Promotes the raw Parquet file to a fully managed Iceberg table:

```sql
CREATE TABLE penguins_iceberg()
USING ICEBERG
WITH (load_from = 's3://wildlife/raw/penguins.parquet');

-- Verify it's an Iceberg table
SELECT catalog_name, table_namespace, table_name, metadata_location 
FROM iceberg_tables 
WHERE table_name = 'penguins_iceberg';
```

### Step 4: ACID Operations

```bash
task demo:modify
```

Demonstrates transactional DELETE on lake data:

```sql
-- Count before
SELECT count(*) FROM penguins_iceberg WHERE species = 'Chinstrap';
-- Returns: 68

-- Delete Chinstrap penguins
DELETE FROM penguins_iceberg WHERE species = 'Chinstrap';

-- Count after
SELECT count(*) FROM penguins_iceberg WHERE species = 'Chinstrap';
-- Returns: 0
```

### Run Full Demo

```bash
task demo:all
```

Runs all steps in sequence.

## Available Tasks

```bash
task --list
```

### Setup Tasks

| Task | Description |
|------|-------------|
| `setup:all` | Run all setup tasks |
| `setup:env` | Create .env from .env.example |
| `setup:aws` | Set up local AWS config for LocalStack |

### pg_lake Tasks

| Task | Description |
|------|-------------|
| `pg_lake:clone` | Clone pg_lake docker folder (sparse checkout) |
| `pg_lake:up` | Start pg_lake services (builds on first run) |
| `pg_lake:down` | Stop pg_lake services |
| `pg_lake:logs` | View pg_lake service logs |
| `pg_lake:teardown` | Stop services and remove volumes |
| `pg_lake:settings` | Show pg_lake configuration settings |

### Health Check Tasks

| Task | Description |
|------|-------------|
| `check:all` | Check all services (pg, localstack, s3) |
| `check:pg` | Check if pg_lake PostgreSQL is running |
| `check:localstack` | Check if LocalStack is running |
| `check:s3` | Check if S3 operations work (create/delete test bucket) |

### Data Tasks

| Task | Description |
|------|-------------|
| `data:download` | Download penguins CSV from GitHub |
| `data:convert` | Convert CSV to Parquet format |
| `data:penguins` | Download and convert (combined) |
| `data:clean` | Remove data files |

### S3 Tasks

| Task | Description |
|------|-------------|
| `s3:create-bucket` | Create S3 bucket in LocalStack |
| `s3:upload` | Upload data files to S3 |
| `s3:list` | List files in S3 bucket |
| `s3:list-buckets` | List all S3 buckets |

### Demo Tasks

| Task | Description |
|------|-------------|
| `demo:secret` | Create wildlife S3 secret for S3 bucket |
| `demo:reset` | Reset to clean state (drops tables, extension, resets S3) |
| `demo:init` | Initialize pg_lake extension |
| `demo:foreign-table` | Part 1 - Create foreign table for Parquet |
| `demo:iceberg` | Part 2 - Upgrade to Iceberg |
| `demo:modify` | Part 3 - ACID operations |
| `demo:all` | Run full demo sequence |
| `demo:teardown` | Full teardown (stop containers, remove volumes, clean data) |

### SQL Tasks

| Task | Description |
|------|-------------|
| `sql:run FILE=<path>` | Run SQL on PostgreSQL |
| `sql:run-duckdb FILE=<path>` | Run SQL on DuckDB/pgduck_server |

### DuckDB Tasks

| Task | Description |
|------|-------------|
| `duckdb:list-secrets` | List all DuckDB secrets |

### Iceberg Tasks

| Task | Description |
|------|-------------|
| `iceberg:list-tables` | List all Iceberg tables |
| `iceberg:list-snapshots` | List snapshots for penguins_iceberg (time travel history) |

> **Tip**: Use `task iceberg:list-snapshots TABLE=my_table` to query a different table.

## Configuration

Environment variables are stored in `.env` (copy from `.env.example`):

```bash
# Data paths
DATA_DIR=./data
PENGUINS_CSV_URL=https://raw.githubusercontent.com/dataprofessor/code/master/streamlit/part3/penguins_cleaned.csv

# S3/LocalStack
S3_BUCKET=wildlife
S3_PARQUET_KEY=raw/penguins.parquet
AWS_ENDPOINT_URL=http://localhost:4566
AWS_DEFAULT_REGION=us-east-1

# Postgres
PG_CONTAINER=pg_lake
DB_USER=postgres
DB_NAME=postgres
```

## Troubleshooting

### Cannot connect to PostgreSQL

Ensure pg_lake services are running:

```bash
cd /path/to/pg_lake/docker
docker-compose ps
```

### S3 upload fails

Verify LocalStack is running:

```bash
curl http://localhost:4566/_localstack/health
```

### Extension not found

Make sure you built pg_lake with the correct PostgreSQL version:

```bash
cd /path/to/pg_lake/docker
task compose:up PG_MAJOR=18
```

## Resources

### Core Technologies

- [pg_lake](https://github.com/Snowflake-Labs/pg_lake) - PostgreSQL extension for data lake integration
- [Apache Iceberg](https://iceberg.apache.org/) - Open table format for large analytic datasets
- [DuckDB](https://duckdb.org/) - In-process analytical database (powers pg_lake queries)
- [Apache Parquet](https://parquet.apache.org/) - Columnar storage file format

### Tools Used

- [Task](https://taskfile.dev/) - Task runner / build tool (simpler alternative to Make)
- [uv](https://docs.astral.sh/uv/) - Fast Python package installer and resolver
- [LocalStack](https://localstack.cloud/) - Local AWS cloud emulator
- [direnv](https://direnv.net/) - Environment variable manager (optional)
- [Docker](https://www.docker.com/) - Container platform

### Data

- [Palmer Penguins Dataset](https://allisonhorst.github.io/palmerpenguins/) - Antarctic penguin measurements
- [pg_lake Local Development Guide](https://github.com/Snowflake-Labs/pg_lake/blob/main/docker/LOCAL_DEV.md)

## Acknowledgments

- Thanks to [@dataprofessor](https://github.com/dataprofessor) for providing the cleaned Palmer Penguins dataset used in this demo
- Thanks to [Allison Horst](https://allisonhorst.github.io/palmerpenguins/) for the original Palmer Penguins dataset

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
