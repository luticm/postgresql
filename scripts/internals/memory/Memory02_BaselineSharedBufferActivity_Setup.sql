/*******************************************************************************************
***
***   Description : Setup for the baseline shared-buffer activity demonstration.
***                 This script is rerunnable and creates objects only in memory_lab.
***
*******************************************************************************************/

-- pg_buffercache is used only to make the cold-cache starting point deterministic.
-- It is available in the local PG18 Docker image and requires a superuser to install.
CREATE EXTENSION IF NOT EXISTS pg_buffercache;

CREATE SCHEMA IF NOT EXISTS memory_lab;

CREATE TABLE IF NOT EXISTS memory_lab.shared_buffer_baseline
(
	id bigint PRIMARY KEY,
	payload text NOT NULL
);

-- Create enough heap data to exceed the 128 MB shared_buffers setting used by docker/pg18.
-- A full scan cannot leave the entire relation resident in shared buffers, making cache
-- turnover visible when this lab is run repeatedly.
INSERT INTO memory_lab.shared_buffer_baseline
(
	id,
	payload
)
SELECT
	series_id,
	repeat(md5(series_id::text), 16)
FROM generate_series(1, 500000) AS source(series_id)
ON CONFLICT (id) DO NOTHING;

VACUUM ANALYZE memory_lab.shared_buffer_baseline;

SELECT
	pg_size_pretty(pg_relation_size('memory_lab.shared_buffer_baseline')) AS heap_size,
	pg_size_pretty(pg_total_relation_size('memory_lab.shared_buffer_baseline')) AS total_size,
	current_setting('shared_buffers') AS shared_buffers;

--TRUNCATE TABLE memory_lab.shared_buffer_baseline;