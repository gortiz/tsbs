#!/bin/bash
# showcases the ftsb 3 phases for timescaledb
# - 1) data and query generation
# - 2) data loading/insertion
# - 3) query execution

MAX_RPS=${MAX_RPS:-"0"}
MAX_QUERIES=${MAX_QUERIES:-"1000"}
PASSWORD=${PASSWORD:-"password"}

mkdir -p /tmp/bulk_data

# generate queries
$GOPATH/bin/tsbs_generate_data --format timescaledb --use-case cpu-only --scale 1000 --seed 123 --file /tmp/bulk_data/timescaledb_data

# generate queries
$GOPATH/bin/tsbs_generate_queries --queries=${MAX_QUERIES} --format timescaledb --use-case cpu-only --scale 100 --seed 123 --query-type lastpoint     --file /tmp/bulk_data/timescaledb_query_lastpoint
$GOPATH/bin/tsbs_generate_queries --queries=${MAX_QUERIES} --format timescaledb --use-case cpu-only --scale 100 --seed 123 --query-type cpu-max-all-1 --file /tmp/bulk_data/timescaledb_query_cpu-max-all-1
$GOPATH/bin/tsbs_generate_queries --queries=${MAX_QUERIES} --format timescaledb --use-case cpu-only --scale 100 --seed 123 --query-type high-cpu-1    --file /tmp/bulk_data/timescaledb_query_high-cpu-1

# insert benchmark
$GOPATH/bin/tsbs_load_timescaledb --prometheus-push-gateway-uri="http://localhost:9091" --pass=${PASSWORD} --postgres="sslmode=disable port=5433" --db-name=benchmark --host=127.0.0.1 --user=postgres --workers=1 --file=/tmp/bulk_data/timescaledb_data --results-file="timescaledb_load_results.json"

# queries benchmark
$GOPATH/bin/tsbs_run_queries_timescaledb --prometheus-push-gateway-uri="http://localhost:9091" --max-rps=${MAX_RPS} --hdr-latencies="${MAX_RPS}rps_timescaledb_query_lastpoint.hdr" --pass=${PASSWORD} --postgres="sslmode=disable port=5433" --db-name=benchmark --hosts=127.0.0.1 --user=postgres --workers=1 --max-queries=${MAX_QUERIES} --file=/tmp/bulk_data/timescaledb_query_lastpoint --results-file="timescaledb_query_lastpoint_results.json"
$GOPATH/bin/tsbs_run_queries_timescaledb --prometheus-push-gateway-uri="http://localhost:9091" --max-rps=${MAX_RPS} --hdr-latencies="${MAX_RPS}rps_timescaledb_query_cpu-max-all-1.hdr" --pass=${PASSWORD} --postgres="sslmode=disable port=5433" --db-name=benchmark --hosts=127.0.0.1 --user=postgres --workers=1 --max-queries=${MAX_QUERIES} --file=/tmp/bulk_data/timescaledb_query_cpu-max-all-1  --results-file="timescaledb_query_cpu-max-all-1_results.json"
$GOPATH/bin/tsbs_run_queries_timescaledb --prometheus-push-gateway-uri="http://localhost:9091" --max-rps=${MAX_RPS} --hdr-latencies="${MAX_RPS}rps_timescaledb_query_high-cpu-1.hdr" --pass=${PASSWORD} --postgres="sslmode=disable port=5433" --db-name=benchmark --hosts=127.0.0.1 --user=postgres --workers=1 --max-queries=${MAX_QUERIES} --file=/tmp/bulk_data/timescaledb_query_high-cpu-1 --results-file="timescaledb_query_high-cpu-1_results.json"
