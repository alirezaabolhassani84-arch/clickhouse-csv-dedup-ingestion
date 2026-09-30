-- Check how old the active parts of final_stats are (merge monitoring)
SELECT table, partition, name AS part_name, modification_time, rows,
       dateDiff('second', modification_time, now()) AS age_seconds
FROM system.parts
WHERE table = 'final_stats' AND active = 1
ORDER BY modification_time DESC;
