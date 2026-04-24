#!/bin/bash

OUTPUT_FILE=$1

[[ -z "${OUTPUT_FILE}" ]] && echo "usage: generate-appws-spec.sh <output-file>" && exit 1
[[ -z "${DEFAULT_FILE_STORAGE_CLASS}" ]] && echo "Required DEFAULT_FILE_STORAGE_CLASS env var not found" && exit 1

echo "OUTPUT_FILE ....................... ${OUTPUT_FILE}"
echo "DEFAULT_FILE_STORAGE_CLASS  ....... ${DEFAULT_FILE_STORAGE_CLASS}"

echo 'mas_appws_spec:
  bindings:
    jdbc: workspace-application
  settings:
    deployment:
      size: small
    routes:
      timeout: 600s
    storage:
      log:
        class: '${DEFAULT_FILE_STORAGE_CLASS}'
        mode: ReadWriteOnce
        size: 30
      userfiles:
        class: '${DEFAULT_FILE_STORAGE_CLASS}'
        mode: ReadWriteOnce
        size: 50
    dwfagents: []
    db:
      maxconnpoolsize: 100
' > $OUTPUT_FILE


echo "App workspace spec yaml generated: ${OUTPUT_FILE}"
