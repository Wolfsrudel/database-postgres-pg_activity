-- Get data from pg_activity from pg 9.6 to 10
-- In this version there is no way to distinguish parallel workers from the rest
-- NEW pg_stat_activity.waiting => pg_stat_activity.wait_event
SELECT
      a.pid AS pid,
      a.application_name AS application_name,
      a.datname AS database,
      CASE WHEN a.client_addr IS NULL
          THEN 'local'
          ELSE a.client_addr::TEXT
      END AS client,
      EXTRACT(epoch FROM (NOW() - a.{duration_column})) AS duration,
      a.wait_event AS wait,
      a.usename AS user,
      a.state AS state,
      convert_from(replace(a.query, '\', '\\')::bytea, coalesce(pg_catalog.pg_encoding_to_char(b.encoding), 'UTF8')) AS query,
      false AS is_parallel_worker
  FROM
      pg_stat_activity a
      LEFT OUTER JOIN pg_database b ON a.datid = b.oid
 WHERE
      state <> 'idle'
  AND pid <> pg_backend_pid()
  AND CASE WHEN %(min_duration)s = 0
          THEN true
          ELSE extract(epoch from now() - {duration_column}) > %(min_duration)s
      END
  AND CASE WHEN %(dbname_filter)s IS NULL THEN true
      ELSE a.datname ~* %(dbname_filter)s
      END
ORDER BY
      EXTRACT(epoch FROM (NOW() - a.{duration_column})) DESC;