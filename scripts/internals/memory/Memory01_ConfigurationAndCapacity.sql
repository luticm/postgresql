/*******************************************************************************************
***
***   Description : Relates the Docker container memory limit to PostgreSQL memory settings
***                 and the current session's memory contexts.
***
*******************************************************************************************/

-- PostgreSQL does not dynamically resize these settings when host or container RAM changes.
-- shared_buffers requires a server restart; work_mem and temp_buffers can change per session.
SELECT
	name,
	setting,
	unit,
	context,
	boot_val,
	reset_val
FROM pg_settings
WHERE name IN
(
	'shared_buffers',
	'work_mem',
	'maintenance_work_mem',
	'temp_buffers',
	'max_connections'
)
ORDER BY name;

-- This local Docker-specific section reads cgroup v2 files from inside the container.
-- It requires superuser or pg_read_server_files, and will not work on managed PostgreSQL.
WITH cgroup_memory AS
(
	SELECT
		nullif(btrim(pg_read_file('/sys/fs/cgroup/memory.max')), 'max')::bigint AS limit_bytes,
		btrim(pg_read_file('/sys/fs/cgroup/memory.current'))::bigint AS current_bytes
),
postgresql_memory AS
(
	SELECT
		pg_size_bytes(current_setting('shared_buffers')) AS shared_buffers_bytes,
		pg_size_bytes(current_setting('work_mem')) AS work_mem_bytes,
		pg_size_bytes(current_setting('maintenance_work_mem')) AS maintenance_work_mem_bytes,
		pg_size_bytes(current_setting('temp_buffers')) AS temp_buffers_bytes,
		current_setting('max_connections')::integer AS max_connections
)
SELECT
	pg_size_pretty(limit_bytes) AS container_memory_limit,
	pg_size_pretty(current_bytes) AS container_memory_current,
	pg_size_pretty(shared_buffers_bytes) AS shared_buffers,
	ROUND(100.0 * shared_buffers_bytes / limit_bytes, 2) AS shared_buffers_percent_of_container_limit,
	pg_size_pretty(work_mem_bytes) AS work_mem_per_sort_or_hash_node,
	pg_size_pretty(maintenance_work_mem_bytes) AS maintenance_work_mem_per_maintenance_operation,
	pg_size_pretty(temp_buffers_bytes) AS temp_buffers_per_session,
	max_connections
FROM cgroup_memory
CROSS JOIN postgresql_memory;

-- This is the current backend only, not total PostgreSQL memory usage.
-- Run it before and after a memory-intensive query to see session-local allocations.
SELECT
	name,
	ident,
	level,
	pg_size_pretty(total_bytes) AS total_allocated,
	pg_size_pretty(used_bytes) AS used,
	pg_size_pretty(free_bytes) AS free
FROM pg_backend_memory_contexts
ORDER BY total_bytes DESC;

-- Capacity rule of thumb:
-- total PostgreSQL memory is not shared_buffers + work_mem. work_mem can be allocated by
-- several plan nodes, parallel workers, and concurrent sessions. Leave headroom for backend
-- memory, OS page cache, connections, maintenance, and the container runtime.