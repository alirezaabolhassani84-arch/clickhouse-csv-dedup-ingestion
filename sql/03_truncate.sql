-- WARNING: never truncate id_memory or final_stats without a deliberate reason.
-- Doing so erases the de-duplication history / aggregated totals.
-- TRUNCATE
TRUNCATE TABLE demo.raw_data;
TRUNCATE TABLE demo.id_memory;
TRUNCATE TABLE demo.final_stats;
