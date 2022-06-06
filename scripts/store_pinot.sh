#!/usr/bin/env bash

set -e
set -x
# This script assumes Apache Pinot is up and running.

# Ensure loader is available
EXE_FILE_NAME=${EXE_FILE_NAME:-$(which tsbs_generate_data)}
if [[ -z "$EXE_FILE_NAME" ]]; then
    echo "tsbs_generate_data not available. It is not specified explicitly as \$EXE_FILE_NAME and not found in \$PATH"
    exit 1
fi

# Ensure pinot-admin is available
PINOT_ADMIN_FILE_NAME=${PINOT_ADMIN_FILE_NAME:-$(which pinot-admin.sh)}
if [[ -z "$PINOT_ADMIN_FILE_NAME" ]]; then
    echo "tsbs_generate_data not available. It is not specified explicitly as \$EXE_FILE_NAME and not found in \$PATH"
    exit 1
fi

USE_CASE=${USE_CASE:-"iot"}
SEED=${SEED:-"123"}
SCALE=${SCALE:-"5000"}
TIMESTAMP_START=${TIMESTAMP_START:-"2020-01-01T00:00:00Z"}
TIMESTAMP_END=${TIMESTAMP_END:-"2020-01-10T00:00:00Z"}
LOG_INTERVAL=${LOG_INTERVAL:-"60s"}
FORMAT=${FORMAT:-"pinot"}
LINES_PER_SEGMENT=${LINES_PER_SEGMENT:-10000000}
OUTPUT_FILE_TEMPLATE=${OUTPUT_FILE_TEMPLATE:-"readings.%0.5d.csv"}
HEADER=${HEADER:-"name,fleet,driver,model,device_version,load_capacity,fuel_capacity,nominal_fuel_consumption,timestamp,latitude,longitude,elevation,velocity,heading,grade,fuel_consumption"}

ADD_TABLE=${ADD_TABLE:-"true"}
UPLOAD_SEGMENT=${UPLOAD_SEGMENT:-"true"}

TABLE_CONFIG_FILE=${TABLE_CONFIG_FILE:-"readings_config.json"}
SCHEMA_FILE=${SCHEMA_FILE:-"readings_schema.json"}

CSV_DIR=${CSV_DIR:-"csv"}
SEGMENT_DIR=${SEGMENT_DIR:-"segment"}

CONTROLLER_HOST_ARG=${CONTROLLER_HOST:+"-controllerHost $CONTROLLER_HOST"}
CONTROLLER_PORT=${CONTROLLER_HOST:-"9000"}

if [ -n "$ADD_TABLE" ] ; then
  ${PINOT_ADMIN_FILE_NAME} AddTable -exec \
    -tableConfigFile $TABLE_CONFIG_FILE \
    $CONTROLLER_HOST_ARG \
    -controllerPort $CONTROLLER_PORT \
    -schemaFile $SCHEMA_FILE || true
fi

mkdir -p $CSV_DIR
mkdir -p $SEGMENT_DIR

${EXE_FILE_NAME} --use-case=$USE_CASE \
                --seed=$SEED \
                --scale=$SCALE \
                --timestamp-start=$TIMESTAMP_START \
                --timestamp-end=$TIMESTAMP_END \
                --log-interval=$LOG_INTERVAL \
                --format=$FORMAT |
                tail -n +5 |
                awk -v l=$LINES_PER_SEGMENT "
                                            (NR==1){
                                               file=sprintf(\"$CSV_DIR/$OUTPUT_FILE_TEMPLATE\",c);
                                            }
                                            (NR%l==1) {
                                               close(file);
                                               file=sprintf(\"$CSV_DIR/$OUTPUT_FILE_TEMPLATE\",++c)
                                               print \"$HEADER\" > file
                                            }
                                            {print > file}"


$PINOT_ADMIN_FILE_NAME CreateSegment \
  -tableConfigFile $TABLE_CONFIG_FILE \
  -format CSV -overwrite \
  -schemaFile $SCHEMA_FILE \
  -dataDir $CSV_DIR \
  -outDir $SEGMENT_DIR


if [ -n "$UPLOAD_SEGMENT" ] ; then
  $PINOT_ADMIN_FILE_NAME UploadSegment \
    -tableName readings \
    $CONTROLLER_HOST_ARG \
    -controllerPort $CONTROLLER_PORT \
    -segmentDir $SEGMENT_DIR
fi