# ClickHouse CSV Ingestion with Automatic De-duplication

A ClickHouse pipeline that loads CSV files, **never counts a duplicate
`statisticid` twice**, and keeps the aggregated totals fresh with automatic
fast background merging. Everything is done inside ClickHouse using materialized
views: no external scheduler and no manual `OPTIMIZE`.

## The problem

Input CSV columns: `statisticid, logicid, timestamp, logiccomponentid, count`

1. `statisticid` should be unique, but the same id can arrive again in another file, or even in the same file.
2. `SummingMergeTree` only sums rows during background merges, so the final totals are not available instantly.

## Architecture

```
                 +--> mv_to_memory --> id_memory   (ReplacingMergeTree, permanent de-dup memory)
CSV --> raw_data-+
 (MergeTree)     +--> mv_to_stats  --> final_stats (SummingMergeTree + force-merge)
```

Both materialized views fire synchronously on every `INSERT` into `raw_data`.

| Object | Engine | Role | May be cleared? |
|---|---|---|---|
| `raw_data` | MergeTree | Raw landing zone for CSV rows | Yes, with caution |
| `id_memory` | ReplacingMergeTree | Every `statisticid` ever seen | **Never** |
| `final_stats` | SummingMergeTree | `logicid`, `logiccomponentid`, `total_count` | **Never** |
| `mv_to_memory` | Materialized view | Records every `statisticid` in `id_memory` | - |
| `mv_to_stats` | Materialized view | Adds sums only for ids **not** in `id_memory` | - |

### Key design points

- `timestamp` is a `String` because formats like `9/7/2026 23:30` are not natively parsed by ClickHouse.
- The core de-dup line in `mv_to_stats` is `WHERE statisticid NOT IN (SELECT statisticid FROM demo.id_memory)`.
- `final_stats` uses two settings so equal keys are summed within about 30 seconds of an insert:
  - `min_age_to_force_merge_seconds = 30`: any part older than 30 s is merged, regardless of size or count.
  - `min_age_to_force_merge_on_partition_only = 0`: a single part can force-merge on its own age (important for tables without a partition key).
- Trade-off: a smaller value means more frequent merges and more CPU / disk I/O. For a small table, 30-60 s is a good balance.

## Usage

```bash
# 1) create the database, tables and materialized views
clickhouse-client --multiquery < sql/01_schema.sql

# 2) load a CSV
clickhouse-client --query "INSERT INTO demo.raw_data FORMAT CSVWithNames" < your_file.csv

# 3) look at the results
clickhouse-client --multiquery < sql/02_inspect.sql
```

`sql/04_monitor_parts.sql` shows the age of `final_stats` parts so you can watch the merges.

## Repository layout

```
sql/          # schema, inspect queries, truncate helpers, part monitoring
docs/         # presentation about the design
```

The names used here (`demo` database, table names) are generic examples; rename them to fit your environment.
