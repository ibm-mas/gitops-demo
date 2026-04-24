#!/bin/bash

OUTPUT_FILE=$1

[[ -z "${OUTPUT_FILE}" ]] && echo "usage: generate-app-spec.sh <output-file>" && exit 1
[[ -z "${DEFAULT_FILE_STORAGE_CLASS}" ]] && echo "Required DEFAULT_FILE_STORAGE_CLASS env var not found" && exit 1

echo "OUTPUT_FILE ....................... ${OUTPUT_FILE}"
echo "DEFAULT_FILE_STORAGE_CLASS  ....... ${DEFAULT_FILE_STORAGE_CLASS}"

echo 'mas_app_spec:
  settings:
    readOnlyRootFilesystem: true
    storage:
      size: 100Gi
      storageClassName: '${DEFAULT_FILE_STORAGE_CLASS}'
      objectStorageEnabled: false
' > $OUTPUT_FILE


echo "App spec yaml generated: ${OUTPUT_FILE}"
