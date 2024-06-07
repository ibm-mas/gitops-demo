#!/bin/bash

OUTPUT_FILE=$1

[[ -z "${OUTPUT_FILE}" ]] && echo "usage: generate-appws-spec.sh <output-file>" && exit 1
[[ -z "${DEFAULT_FILE_STORAGE_CLASS}" ]] && echo "Required DEFAULT_FILE_STORAGE_CLASS env var not found" && exit 1
[[ -z "${MAS_WORKSPACE_ID}" ]] && echo "Required MAS_WORKSPACE_ID env var not found" && exit 1

echo "OUTPUT_FILE ....................... ${OUTPUT_FILE}"
echo "DEFAULT_FILE_STORAGE_CLASS  ....... ${DEFAULT_FILE_STORAGE_CLASS}"
echo "MAS_WORKSPACE_ID .................. ${MAS_WORKSPACE_ID}"

echo '
mas_appws_spec:
  bindings:
    jdbc: workspace-application
  components:
    base: 
      version: latest
  settings:
    aio:
      install: true
    db:
      dbSchema: maximo
      maxinst:
        bypassUpgradeVersionCheck: false
        db2Vargraphic: true
        demodata: false
        indexSpace: MAXINDEX
        tableSpace: MAXDATA
    deployment:
      buildTag: latest
      defaultJMS: true
      mode: up
      persistentVolumes:
        - accessModes:
            - ReadWriteMany
          mountPath: /DOCLINKS
          pvcName: manage-doclinks
          size: 20Gi
          storageClassName: '${DEFAULT_FILE_STORAGE_CLASS}'
        - accessModes:
            - ReadWriteMany
          mountPath: /bim
          pvcName: manage-bim
          size: 20Gi
          storageClassName: '${DEFAULT_FILE_STORAGE_CLASS}'
        - accessModes:
            - ReadWriteMany
          mountPath: /jms
          pvcName: manage-jms
          size: 20Gi
          storageClassName: '${DEFAULT_FILE_STORAGE_CLASS}'
      serverBundles:
        - additionalServerConfig:
            secretName: '${MAS_WORKSPACE_ID}'-manage-d--sb0--asc--sn
          bundleType: ui
          isDefault: true
          isMobileTarget: true
          isUserSyncTarget: false
          name: ui
          replica: 1
          routeSubDomain: ui
        - additionalServerConfig:
            secretName: '${MAS_WORKSPACE_ID}'-manage-d--sb1--asc--sn
          bundleType: mea
          isDefault: false
          isMobileTarget: false
          isUserSyncTarget: true
          name: mea
          replica: 1
          routeSubDomain: mea
        - additionalServerConfig:
            secretName: '${MAS_WORKSPACE_ID}'-manage-d--sb2--asc--sn
          bundleType: report
          isDefault: false
          isMobileTarget: false
          isUserSyncTarget: false
          name: rpt
          replica: 1
          routeSubDomain: rpt
        - additionalServerConfig:
            secretName: '${MAS_WORKSPACE_ID}'-manage-d--sb3--asc--sn
          bundleType: cron
          isDefault: false
          isMobileTarget: false
          isUserSyncTarget: false
          name: cron
          replica: 1
          routeSubDomain: cron
        - additionalServerConfig:
            secretName: '${MAS_WORKSPACE_ID}'-manage-d--sb4--asc--sn
          bundleType: standalonejms
          isDefault: false
          isMobileTarget: false
          isUserSyncTarget: false
          name: jms
          replica: 1
          routeSubDomain: jms
      serverTimezone: GMT
    languages:
      baseLang: EN
      secondaryLangs: []
' > $OUTPUT_FILE


echo "App workspace spec yaml generated: ${OUTPUT_FILE}"