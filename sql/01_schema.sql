CREATE DATABASE IF NOT EXISTS demo;

-- 1) raw_data: raw CSV input (landing zone)
CREATE TABLE demo.raw_data
(
    statisticid       UInt64,
    logicid           UInt64,
    timestamp         String,
    logiccomponentid  String,
    count             UInt64
)
ENGINE = MergeTree
ORDER BY statisticid;

-- 2) id_memory: permanent de-duplication memory
CREATE TABLE demo.id_memory
(
    statisticid UInt64
)
ENGINE = ReplacingMergeTree
ORDER BY statisticid;

-- 3) MV 1: record every statisticid in id_memory
CREATE MATERIALIZED VIEW demo.mv_to_memory
TO demo.id_memory AS
SELECT statisticid FROM demo.raw_data;

-- 4) final_stats: final output table, with force-merge settings
CREATE TABLE demo.final_stats
(
    logicid           UInt64,
    logiccomponentid  String,
    total_count       UInt64
)
ENGINE = SummingMergeTree(total_count)
ORDER BY (logicid, logiccomponentid)
SETTINGS
    min_age_to_force_merge_seconds = 30,
    min_age_to_force_merge_on_partition_only = 0;

-- 5) MV 2: add sums to final_stats only for new statisticid values
CREATE MATERIALIZED VIEW demo.mv_to_stats
TO demo.final_stats AS
SELECT
    logicid,
    logiccomponentid,
    sum(count) AS total_count
FROM demo.raw_data
WHERE statisticid NOT IN (SELECT statisticid FROM demo.id_memory)
GROUP BY logicid, logiccomponentid;
