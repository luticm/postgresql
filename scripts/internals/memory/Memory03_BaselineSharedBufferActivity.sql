/*******************************************************************************************
***
***   Description : Scenario 1 - Baseline shared-buffer activity.
***                 Run this after Memory02_BaselineSharedBufferActivity_Setup.sql
***                 in the same database.
***
*******************************************************************************************/

-- Keep the plans single-threaded and use the primary-key index so buffer counts are
-- easier to compare. The setup script creates shared_buffer_baseline_pkey on id.
SET max_parallel_workers_per_gather = 0;
SET enable_seqscan = off;

SELECT
	current_setting('shared_buffers') AS shared_buffers,
	pg_size_pretty(pg_relation_size('memory_lab.shared_buffer_baseline')) AS heap_size,
	pg_size_pretty(pg_total_relation_size('memory_lab.shared_buffer_baseline')) AS total_size;

-- Derive predicates from the current table density and shared-buffer configuration.
-- The small range targets 75% of shared_buffers. The large range targets 150%, so it
-- exceeds the pool by 50%. Limits are capped at the highest id in the test table.
CREATE TEMP TABLE memory01_thresholds AS
SELECT
	LEAST(
		max(id),
		floor(
			0.75 * pg_size_bytes(current_setting('shared_buffers'))
			/ (pg_relation_size('memory_lab.shared_buffer_baseline')::numeric / count(*))
		)::bigint
	) AS small_id_limit,
	LEAST(
		max(id),
		floor(
			1.50 * pg_size_bytes(current_setting('shared_buffers'))
			/ (pg_relation_size('memory_lab.shared_buffer_baseline')::numeric / count(*))
		)::bigint
	) AS large_id_limit
FROM memory_lab.shared_buffer_baseline;

SELECT
	small_id_limit,
	large_id_limit,
	ROUND(100.0 * small_id_limit / large_id_limit, 2) AS small_range_percent_of_large_range
FROM memory01_thresholds;

SELECT pc.oid, pc.relname, pn.nspname, pc.relpages, pc.reltuples, pc.relkind
	, pg_catalog.pg_size_pretty((relpages::bigint * current_setting('block_size')::bigint)::bigint) AS size_used
FROM pg_namespace AS pn 
INNER JOIN pg_class AS pc
ON pc.relnamespace = pn.oid
WHERE pn.nspname NOT IN ('pg_catalog', 'information_schema', 'pg_toast')
	AND pc.relkind in ('r', 'p', 'i')
	AND pn.nspname = 'memory_lab';


-- **************** Scenario A: an index range designed to fit in shared_buffers.
-- Eviction output is (buffers_evicted, buffers_skipped, buffers_not_found).
SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline'::regclass);
SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline_pkey'::regclass);

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- Index only scan to illustrate shared buffer usage
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT count(baseline.id)
FROM memory01_thresholds AS thresholds
INNER JOIN memory_lab.shared_buffer_baseline AS baseline
	ON baseline.id <= thresholds.small_id_limit;

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- First index range scan + loopkup (Postgres doesn't show bookmark lookup)
EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING OFF)
SELECT sum(length(baseline.payload))
FROM memory01_thresholds AS thresholds
INNER JOIN memory_lab.shared_buffer_baseline AS baseline
	ON baseline.id <= thresholds.small_id_limit;

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- relation	buffers	size_mb
-- memory_lab.shared_buffer_baseline	12289	96.01
-- memory_lab.shared_buffer_baseline_pkey	473	3.70

-- Repeat the same range: expect the data pages to be served predominantly from shared
-- buffers, reported as "shared hit" in the execution plan.

-- 2nd index range scan + loopkup (Postgres doesn't show bookmark lookup)
EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING OFF)
SELECT sum(length(baseline.payload))
FROM memory01_thresholds AS thresholds
INNER JOIN memory_lab.shared_buffer_baseline AS baseline
	ON baseline.id <= thresholds.small_id_limit;

--               Buffers: shared hit=12761

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- **************** Scenario B: an index range 50% larger than shared_buffers.
SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline'::regclass);
SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline_pkey'::regclass);

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- First oversized indexed range scan: expect shared reads.
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT sum(length(baseline.payload))
FROM memory01_thresholds AS thresholds
INNER JOIN memory_lab.shared_buffer_baseline AS baseline
	ON baseline.id <= thresholds.large_id_limit;

-- Buffers: shared read=25519

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- Repeat the oversized range: it cannot fit entirely in shared_buffers. The plan may
-- still report some shared hits for recently used pages, but reads remain expected.
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT sum(length(baseline.payload))
FROM memory01_thresholds AS thresholds
INNER JOIN memory_lab.shared_buffer_baseline AS baseline
	ON baseline.id <= thresholds.large_id_limit;

--               Buffers: shared read=25519
-- Intersting to noticed that this had ZERO shared hits. My hypothesis is the index scan will evict pages from shared_buffers 
-- as it progresses, preventing subsequent accesses from hitting the cache.

-- Trying to bring a backward index scan...
EXPLAIN (ANALYZE, VERBOSE, BUFFERS, TIMING OFF)
SELECT sum(length(payload))
FROM
(
    SELECT baseline.payload
    FROM memory01_thresholds AS thresholds
    INNER JOIN memory_lab.shared_buffer_baseline AS baseline
        ON baseline.id <= thresholds.large_id_limit
    ORDER BY baseline.id DESC
) AS descending_range;

--               Buffers: shared hit=4647 read=32437
-- Can see some hits due to the backward scan accessing recently used pages.
-- Number of pages accessed is 32437, not 25519... 
-- Interesting observation: the backward scan can't use the index to navigate to the proper block and then scan backward.
  -- Execution plan does the backward scan on all index, then thru the nested loop it applies the join predicate
  -- I was expecting this operation to be pushed down to the index scan.

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;


-- ******************** Scenario C: full table scan, larger than shared_buffers.
SET enable_seqscan = on;

SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline'::regclass);
SELECT pg_buffercache_evict_relation('memory_lab.shared_buffer_baseline_pkey'::regclass);

-- Top 10 shared_memory consumers
SELECT 
  c.oid::regclass AS relation,
  count(*) AS buffers,
  round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- First full scan: expect shared reads.
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT sum(length(payload))
FROM memory_lab.shared_buffer_baseline;

--         Buffers: shared read=35715

-- Top 10 shared_memory consumers
SELECT 
c.oid::regclass AS relation,
count(*) AS buffers,
round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

-- relation	buffers	size_mb
-- memory_lab.shared_buffer_baseline	188	1.47
-- memory_lab.shared_buffer_baseline	94	0.73

-- Why I'm not seeing memory_lab.shared_buffer_baseline ocuppying majority of buffer pool?
-- Explanation seems to be in the ring buffer used in seq scans to avoid buffer pool trashing
  -- Need to do deeper investigation to confirm, but seems correct.

-- Repeat the full scan: expect few or no shared hits because the relation is larger
-- than the buffer pool and the forward scan replaces pages before it reaches them again.
EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT sum(length(payload))
FROM memory_lab.shared_buffer_baseline;

SELECT 
c.oid::regclass AS relation,
count(*) AS buffers,
round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;


-- I could try to use pg_prewarm for illustration

CREATE EXTENSION IF NOT EXISTS pg_prewarm;
select pg_prewarm('memory_lab.shared_buffer_baseline'::regclass);

SELECT 
c.oid::regclass AS relation,
count(*) AS buffers,
round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)
SELECT sum(length(payload))
FROM memory_lab.shared_buffer_baseline;

--         Buffers: shared hit=16040 read=19675

SELECT 
c.oid::regclass AS relation,
count(*) AS buffers,
round(count(*) * 8 / 1024.0, 2) AS size_mb
FROM pg_buffercache b
JOIN pg_class c ON b.relfilenode = pg_relation_filenode(c.oid)
GROUP BY c.oid
ORDER BY buffers DESC
LIMIT 10;

DROP EXTENSION pg_prewarm;
RESET enable_seqscan;
RESET max_parallel_workers_per_gather;