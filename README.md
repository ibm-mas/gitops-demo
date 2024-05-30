# Maximo Application Suite GitOps Demonstration

The following is a step-by-step demonstration that you can work through to install MAS on AWS via GitOps using the Helm Charts in [ibm-mas/gitops](https://github.com/ibm-mas/gitops) and the MAS CLI. Please note:
- You do not *need* to use the MAS CLI to use our ArgoCD applications, but at this stage of development there is no documentation in place for this. 
- It is possible to use other cloud providers, but this has not been tested sufficiently for demonstration yet.
- It is possible for ArgoCD to run on one cluster, managing MAS instances across multiple other clusters. In the interests of simplicity, in this demonstration we will restrict the deployment to a single MAS Instance running in the same cluster as ArgoCD.
- For brevity, we only install the **Manage** MAS application here, but all of the MAS applications are supported.

The process boils down to the following steps:
  - Provision a ROSA cluster
  - Configure AWS Secrets Manager
  - Creating a Git repository to hold your configuration files
  - Install and configure ArgoCD
  - Create the  **Account Root Application**
  - Install Mongo DB on the cluster
  - Create secrets in Secrets Manager and push config files to your Config Git repository

The final step is achieved here using various `gitops` functions provided by the MAS CLI. These have been structured primarily to suit IBM Internal processes. We would like to provide a more streamlined and generic CLI/utility to achieve this in future iterations.


### Setup Secrets Manager
Set up [AWS Secrets Manager](https://us-east-2.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-2), and [create an access key](https://us-east-1.console.aws.amazon.com/iam/home#/security_credentials?section=IAM_credentials)


### Start the MAS CLI image and mount the demo files

If you haven't already, clone this repository to your local machine. This is so we can mount some included configuration files into the MAS CLI container for use later.
```bash
GITOPS_DEMO_PATH=~/gitops-demo
git clone git@github.com:ibm-mas/gitops-demo --branch 002 ${GITOPS_DEMO_PATH}
```

Now run the version of the CLI image used in this demonstration, mounting the files from the gitops-demo repo as follows:

```bash
docker run -v $GITOPS_DEMO_PATH/files:/demo-files -ti --pull always quay.io/ibmmas/cli:8.1.0-pre.demo2
```

### Provision a ROSA Cluster
> TODO: update this
```bash
export IBMCLOUD_APIKEY=xxx
mas provision-roks -r mas-development -c gitopsdemo -v 4.12_openshift --worker-count 3 --worker-flavor b3c.16x64.300gb --worker-zone lon02 --no-confirm
```

When this completed you will be logged into the OCP cluster ready to continue.

### Setup common environment variables

The CLI allows arguments to be passed in both via command-line arguments and environment variables. For repeated parameters that are used by many of the functions that we are going to call, we are going to export them as environment variables so we don't have to specify them every time. Please customize the values in the script below, then run it in your mas-cli terminal session:

```bash

# This will determine the name of the top-level folder in your Git Config repo
# It will also be provided in the configuration of the Account Root Application
export ACCOUNT_ID="dev"

# This will determine second-level folder in your Git Config repo.
# It will also be included in the names of the Applications that ArgoCD will generate
# Must be less than 15 characters (see "Naming Length Restrictions" below)
export CLUSTER_ID="useast1a"

# This will determine the OCP cluster that ArgoCD targets.
# In this tutorial, we are deploying a single MAS instance in the same cluster as ArgoCD.
export CLUSTER_URL="https://kubernetes.default.svc"

# This will determine third-level folder in your Git Config repo.
# It will also be included in the names of the Applications that ArgoCD will generate
# Must be less than 15 characters (see "Naming Length Restrictions" below)
export MAS_INSTANCE_ID="inst1"

# This will determine the name of the MAS Suite and Application workspace in your deployment
export MAS_WORKSPACE_ID="demo2ws"
export MAS_WORKSPACE_NAME="demo2 workspace"

# These will be used to configure the AVP plugin in ArgoCD so it is capable of retrieving secrets from AWS Secrets Manager
# They will also be used to configure various secrets automatically by some of the CLI functions we are about to call
export SM_AWS_ACCOUNT_ID="xxxxx"
export SM_AWS_REGION="us-east-1"
export SM_AWS_SECRET_ACCESS_KEY="xxx"
export SM_AWS_ACCESS_KEY_ID="xxx"

# This will be substituted into generated configuration .yaml files to reference secrets
# and allow them to be resolved by the AVP plugin when rendering Helm Charts
export SECRETS_PATH="arn:aws:secretsmanager:${SM_AWS_REGION}:${SM_AWS_ACCOUNT_ID}:secret"
```

> **Naming Length Restrictions** Because we stitch together the different IDs that form the hierarchy together we need to ensure that the total length is less than the 64 character limit of ArgoCD applications, to achieve this follow these restrictions when setting values for `--cluster-id` (`CLUSTER_ID`), and `--mas-instance-id` (`MAS_INSTANCE_ID`):
> - **Cluster ID**: 15 characters. Must be unique within an account.
> - **MAS instance ID**: 15 characters. Must be unique within a cluster.

### Setup your gitops repository
Git repositories are used to supply ArgoCD with both the **Helm Charts** for the MAS installation (the _source_ Git repo), as well as a collection of per-cluster/instance **configuration** files used to render those templates into Kubernetes (the _config_ Git repo).

The **Helm Charts** are provided by IBM in the public [ibm-mas/gitops](https://github.com/ibm-mas/gitops) repository on github.com.

> It is possible to source Helm charts from elsewhere (i.e. your own fork of ibm-mas/gitops) but this is not covered in this demonstration.

For the **configuration** files you will need to setup a new git repository in your preferred provider and supply its details to the CLI via some environment variables. In your mas cli terminal session, run the following, subtituting in the values for your git repository:

```bash
export GITOPS_VERSION="master"
export GITHUB_HOST="github.com"
export GITHUB_ORG="ibm-mas"
export GITHUB_REPO="gitops-demo"
export GIT_BRANCH="002"
export GIT_SSH="false"
```

Create a personal access token in your git provider, ensuring that it has sufficient permissions to read and write from your git repository. This will be used to grant ArgoCD access to your Git repository, and will be used by the MAS CLI commands to push configuration files. Set it in your environment as follows:
```bash
export GITHUB_PAT="xxx"
```

And configure git:
```bash
git config --global user.email "you@example.com"
```



### Bootstrap ArgoCD and create the Account Root Application
The `mas gitops-bootstrap` function will perform the following actions:
- Install ArgoCD operator
- Create ArgoCD instance
- Configure Secret Manager backend for ArgoCD
- Configure ArgoCD ServiceAccount and RBAC
- Enable the ArgoCD Vault plugin
- Configure ArgoCD authentication to your application repository using personal access token
- Patch `openshift-marketplace` and `kube-system` namespaces to allow ArgoCD to manage them
- Add `cluster-admin` access to openshift-gitops ServiceAccount (required for managing SecurityContextContraints)
- Create an ArgoCD project for Maximo Application Suite
- Create the Maximo Application Suite **Account Root Application**

```bash


mas gitops-bootstrap \
  --account-id "${ACCOUNT_ID}" \
  --app-revision demo2 \
  --sm-aws-secret-region "$REGION_ID" \
  --sm-aws-secret-key $SECRET_KEY \
  --sm-aws-access-key $ACCESS_KEY \
  --github-url https://github.com/ibm-mas/gitops-demo \
  --github-revision 001 \
  --github-pat "${GITHUB_PAT}"
```

You will end up with the root application and a single ApplicationSet deployed in ArgoCD as below:
> TODO: update
![ArgoCD post-bootstrap](docs/img/01-bootstrap1.png)

Click "Sync" and after a short delay the application will change to "Synced" status:
> TODO: update
![ArgoCD post-bootstrap](docs/img/01-bootstrap2.png)

This is the only time we will directly make changes on the cluster, with the installation of the **Account Root Application** ArgoCD is ready to automatically deploy all necessary ArgoCD applications as you commit new configuration files to the GitHub configuration repository.

### Generate configuration for the Cluster Root Application
The `mas gitops-cluster` function will perform the following actions:
- Create a new secret in AWS Secrets Manager `${ACCOUNT_ID}/${CLUSTER_ID}/ibm_entitlement` holding the image pull secret for the IBM Container Registry (which contains your IBM entitlement key)
- Create a new secret in AWS Secrets Manager `${ACCOUNT_ID}/${CLUSTER_ID}/aws` holding the access token and secret token for AWS Secrets Manager, which is used by various ArgoCD sync hooks to make updates to secrets
- Generate four new configuration files and push them to your gitops repository
    - `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-mas-cluster-base.yaml`
    - `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-common-services.yaml`
    - `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-mas-cluster-base.yaml`
    - `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-operator-catalog.yaml`
- The post sync hook in the cert manager application will register two new secrets in AWS Secrets Manager:
    - `${ACCOUNT_ID}/${CLUSTER_ID/db2_default_channel`
    - `${ACCOUNT_ID}/${CLUSTER_ID/cluster_domain`


```bash
ICR_USERNAME="xxx"
ICR_PASSWORD="xxx"

mas gitops-cluster \
  --github-push \
  --cluster-url "${CLUSTER_URL}" \
  --icr-username "${ICR_USERNAME}" \
  --icr-password "${ICR_PASSWORD}" \
  --catalog-version v8-240430-amd64 \
  --catalog-image icr.io/cpopen/ibm-maximo-operator-catalog \
  --catalog-action install \
  --common-services-channel v3.23 \
  --common-services-action install
```


Click on the account root application. It will take a few minutes for the cluster root application set to see the new configuration files in your gitops repository. Once this happens, you will see a new cluster root application appear as a child of the cluster application set:
![ArgoCD Account Root](docs/img002/02-cluster2.png)

Open the cluster root application by clicking on the button indicated in the screenshot above, the Operator Catalog and cert manager applications will be visible as children of the cluster root application:

![ArgoCD Cluster Root](docs/img002/02-cluster3.png)


The cert manager application will take a little longer to syncronize because it first waits for the Operator Catalog to be ready before installing the cert manager from that catalog. Within 10 minutes all applications should be reporting Healthy and Synced status. 

![ArgoCD Healthy Cluster Root](docs/img002/02-cluster4.png)


You can safely proceed with the next steps of this demonstration before this happens if you wish since ArgoCD will take care of orchestrating the deployment, ensuring that applications are only synced once its prerequisites are healthy.



### Generate configuration for DRO
The `mas gitops-dro` function will generate one new configuration file in the GitHub working directory:
- `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-dro.yaml`

The post sync hook in ibm-dro will register a new secret in AWS Secrets Manager: `${ACCOUNT_ID}/${CLUSTER_ID/dro`

```bash
mas gitops-dro \
  --github-push
```

After a few minutes you should see two new applications appear as children of the cluster root application. The DRO application itself, along with a small "cleanup" application. The cleanup application contains an ArgoCD [PostDelete hook](https://argo-cd.readthedocs.io/en/stable/user-guide/resource_hooks/) necessary to ensure the DRO application is cleaned up properly when its config is deleted from the git repository. 

![ArgoCD after DRO install](docs/img002/03-dro1.png)

It should take less than 10 minutes for both of these application to reach Healthy/Synced status. Again, you can safely proceed with the next steps of this demonstration before this happens.


### Generate configuration for the DB2U operator application
Later in this demonsration, we plan to install the Manage application in our MAS instance. Manage depends on a DB2 database, and we are going to deploy this database to our cluster. Before we do this, we must install the DB2U operator:

The `mas gitops-db2u` function will generate one new configuration file in the GitHub working directory:
- `/${ACCOUNT_ID}/${CLUSTER_ID}/ibm-db2u.yaml`


```bash
mas gitops-db2u \
  --github-push
```

After a few minutes you should see a new db2u application appear as a child of the cluster root application.

![ArgoCD after DB2U install](docs/img002/04-db2u1.png)

It should take less than 10 minutes for this application to reach Healthy/Synced status. Again, you can safely proceed with the next steps of this demonstration before this happens.


### Generate configuration for MongoDb
> TODO: Could branch these instructions for users wishing to make use of docdb 
> (i.e. `--mongo-provider aws`).

> TODO: what is the cluster-level mongo secret actually used for when mongo-provider=yaml?
> it might be that we only need the user to provide instance-level mongo secret in this demo
>   used by gitops-suite (fetches secret and uses it to update the instance-level secret)
>     we could change this to just pass in mongo yaml and username/password to the suite

> TODO: make it clear that cluster admin mongo creds should be provided here

In this example we are going to be using an off-cluster MongoDB instance.  First, create a configuration file in the following format containing the details required to connect to your MongoDb instance:
```yaml
config:
  configDb: admin
  authMechanism: DEFAULT
  retryWrites: true
  hosts:
    - host: host1
      port: 32500
    - host: host2
      port: 32500
    - host: host3
      port: 32500
certificates:
  - alias: ca
    crt: |
      -----BEGIN CERTIFICATE-----
      <certificate body>
      -----END CERTIFICATE-----
```

Running `mas gitops-mongo` will now generate a new secret (`${ACCOUNT_ID}/${CLUSTER_ID}/mongo`) in AWS Secrets Manager holding all the information necessary to connect, which will be used by the IBM Suite License Service and any instances of IBM Maximo Application Suite installed on this cluster.

```bash
MONGO_INFO_YAML_PATH="xxx"

MONGO_USERNAME="xxx"
MONGO_PASSWORD="xxx"

mas gitops-mongo \
  --mongo-provider yaml \
  --yaml-file $MONGO_INFO_YAML_PATH \
  --mongo-username "${MONGO_USERNAME}" \
  --mongo-password "${MONGO_PASSWORD}"
```

### Configure MongoDb Account for Maximo Application Suite Core Platform
> TODO: could look at automating this step by adding support for "normal" Mongo to
> instance-applications/010-ibm-sync-jobs/templates/00-aws-docdb-add-user_Job.yaml hook
```bash

> TODO: make it clear that a separate user should be setup in Mongo for the MAS instance
> Or, just advise to use the cluster admin creds configured above?

MONGO_INSTANCE_USERNAME="xxx"
MONGO_INSTANCE_PASSWORD="xxx"

aws configure set default.region ${SM_AWS_REGION}
aws configure set aws_access_key_id ${SM_AWS_ACCESS_KEY_ID}
aws configure set aws_secret_access_key ${SM_AWS_SECRET_ACCESS_KEY}
aws secretsmanager create-secret --name "${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/mongo" \
  --secret-string '{"username": "'${MONGO_INSTANCE_USERNAME}'", "password": "'${MONGO_INSTANCE_PASSWORD}'"}'
```

### Configure License File for Maximo Application Suite Core Platform
```bash
LICENSE_FILE_PATH="xxx"

mas gitops-license \
  --license-file "${LICENSE_FILE_PATH}"
```

This will create another new entry to Secret Manager: `${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/license`.  We should now have 8 (TODO: 7?) secrets in total, as below:

```bash
aws configure set default.region ${SM_AWS_REGION}
aws configure set aws_access_key_id ${SM_AWS_ACCESS_KEY_ID}
aws configure set aws_secret_access_key ${SM_AWS_SECRET_ACCESS_KEY}
aws secretsmanager list-secrets --output yaml --no-cli-pager | yq -r '.SecretList[].Name' | grep "^${ACCOUNT_ID}/${CLUSTER_ID}" | sort
aws-dev/mas-4/aws
aws-dev/mas-4/cluster_domain
aws-dev/mas-4/db2_default_channel
aws-dev/mas-4/dro
aws-dev/mas-4/ibm_entitlement
aws-dev/mas-4/mongo   # TODO: remove this if we don't use cluster-level mongo secret in this demo
aws-dev/mas-4/useast1a/license
aws-dev/mas-4/useast1a/mongo
```

### Install Maximo Application Suite Core Platform

```bash
OCP_DOMAIN="---.com"
MAS_DOMAIN="${MAS_INSTANCE_ID}.apps.rosa.${OCP_DOMAIN}"

mas gitops-suite \
  --github-push \
  --mongo-provider aws \
  --user-action "add" \
  --sls-channel 3.x \
  --mas-channel 8.11.x \
  --mas-domain "${MAS_DOMAIN}"
```

This will generate three new configuration files:
- `/${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/ibm-mas-instance-base.yaml`
- `/${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/ibm-mas-suite.yaml`
- `/${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/ibm-sls.yaml`


After a few minutes you should see a new instance root application `TODO` appear as a child of the instance application set under the cluster root application:

![cluster root app after MAS instance installation](docs/img002/05-inst1.png)

Navigate to the instance root application by clicking the button indicated in the screenshot above.
You will see three child applications:
- `sls.demo.us-east-2.demo1.dev1`
- `suite.demo.us-east-2.demo1.dev1`

![instance root app after MAS instance installation](docs/img/05-inst2.png)

After the Suite License Service application is synched you will find one more entry has been created in Secret Manager, created automatically by its post sync hook: `${ACCOUNT_ID}/${CLUSTER_ID}/${MAS_INSTANCE_ID}/sls`.

The Suite application will not change to Healthy status until we complete the next step to configure its connection to DRO, SLS, and MongoDb.

### Configure Maximo Application Suite Core Platform
```bash

mas gitops-mas-config \
  --github-push \
  --mas-config-type mongo \
  --config-action upsert \
  --mas-config-scope system \
  --mongo-provider aws


mas gitops-mas-config \
  --github-push \
  --mas-config-type sls \
  --config-action upsert \
  --mas-config-scope system


DRO_CA_CERTIFICATE_FILE="/tmp/dro_ca.crt"

# > TODO: document use of https://github.com/ibm-mas/ansible-devops/blob/master/ibm/mas_devops/common_tasks/get_ingress_cert.yml in case user doesn't know the name of this secret
oc get secret default-ingress-cert -n openshift-ingress -ojsonpath='{.data.tls\.crt}' | base64 -d > ${DRO_CA_CERTIFICATE_FILE}

# > TODO: where does this come from? It is optional in the script, but if not set, AVP refuses to render the app due to missing secret
MAS_SEGMENT_KEY="xxx"
mas gitops-mas-config \
  --github-push \
  --mas-config-type bas \
  --config-action upsert \
  --mas-config-scope system \
  --dro-contact-email email.com \
  --dro-contact-firstname joe \
  --dro-contact-lastname bloggs \
  --dro-ca-certificate-file $DRO_CA_CERTIFICATE_FILE \
  --mas-segment-key "${MAS_SEGMENT_KEY}"
```

This will generate the 3 configurations that need to be applied to the Core Platform:
- [/demo/us-east-2/demo1/dev1/configs/system.ibm-mas-bas-config.yaml](/demo/us-east-2/demo1/dev1/configs/system.ibm-mas-bas-config.yaml)
- [/demo/us-east-2/demo1/configs/system.ibm-mas-mongo-config.yaml](/demo/us-east-2/demo1/dev1/configs/system.ibm-mas-mongo-config.yaml)
- [/demo/us-east-2/demo1/configs/system.ibm-mas-sls-config.yaml](/demo/us-east-2/demo1/dev1/configs/system.ibm-mas-sls-config.yaml)

Once these three new applications are synced and healthy the Suite application will change to report healthy status as well and you have successfully installed and configured the Maximo Application Suite Core Platform

![ArgoCD during MAS configuration](docs/img/05-suitecfg.png)

Next, we create the Workspace to complete the base configuration of the Maximo Application Suite Core Platform:

```bash
mas gitops-suite-workspace \
  --github-push \
  --mas-instance-id "${MAS_INSTANCE_ID}" \
  --mas-workspace-id "${MAS_WORKSPACE_ID}" \
  --mas-workspace-name "${MAS_WORKSPACE_NAME}"
```

After committing the generated configuration file, ArgoCD will install the 12th and final ArgoCD Application will appear:

![ArgoCD after Workspace commit](docs/img/06-workspace.png)

We can review all the secrets created during the install using the command below:
```bash
aws secretsmanager list-secrets --output yaml --no-cli-pager | yq -r '.SecretList[].Name' | grep "^demo/demo1" | sort
```
![Entries in Secret Manager](docs/img/07-secretmgr.png)


### Configure DB2 Database for MAS Manage Application
First, you'll need to create an EFS filesystem in the same region as your ROSA cluster, then create mount targets for the EFS filesystem in the same VPC and subnets as your ROSA cluster. Please refer to the [AWS documentation](https://docs.aws.amazon.com/efs/latest/ug/gs-step-two-create-efs-resources.html). Once created, determine the name of the associated StorageClass in the cluster (`oc get storageclasses`).


```bash

# The name of the EFS StorageClass in ROSA
export STORAGE_CLASS="efs-xxx"


mas gitops-db2u-database \
  --github-push \
  --db2-version "s11.5.9.0-cn1" \
  --db2-4k-device-support "" \
  --db2-workload "" \
  --db2-meta-storage-class "${STORAGE_CLASS}" \
  --db2-backup-storage-class "${STORAGE_CLASS}" \
  --db2-data-storage-class "${STORAGE_CLASS}" \
  --db2-temp-storage-class "${STORAGE_CLASS}" \
  --db2-logs-storage-class "${STORAGE_CLASS}" \
  --db2-database-db-config-yaml "/demo-files/db2/db2_database_db_config_manage.yaml" \
  --db2-instance-dbm-config-yaml "/demo-files/db2/db2_instance_dbm_config_manage.yaml" \
  --db2-instance-registry-yaml "/demo-files/db2/db2_instance_registry_manage.yaml" \
  --mas-app-id "manage"
```


### 11. Configure MAS with Manage DB2 Database

```bash
mas gitops-mas-config \
  --github-push \
  --mas-config-type jdbc \
  --config-action upsert \
  --mas-config-scope wsapp \
  --mas-app-id "manage" \
  --mas-workspace-id "${MAS_WORKSPACE_ID}" \
  --db2-instance-name "db2wh-${MAS_INSTANCE_ID}-manage"
```


### 12. Install Manage

```bash
mas gitops-suite-app-install \
  --github-push  \
  --mas-app-id  "manage" \
  --mas-app-channel  "8.7.x" \
  --mas-app-catalog-source "ibm-operator-catalog" \
  --mas-app-api-version "apps.mas.ibm.com/v1" \
  --mas-app-kind "ManageApp" \
  --mas-edition "essentials-maintenance"
```


### 13. Configure Manage

```bash

# Run a script to generate YAML containing basic server bundles for Manage
# The exported values of the MAS_INSTANCE_ID and MAS_WORKSPACE_ID env vars will substituted in where appropriate
bash /demo-files/manage/generate-server-bundles.sh

# Run a script to generate YAML containing the spec for the Manage Workspace we are about to create
# The exported values of the STORAGE_CLASS and MAS_WORKSPACE_ID env vars will substituted in where appropriate
bash /demo-files/manage/generate-server-bundles.sh

export DEFAULT_FILE_STORAGE_CLASS="${STORAGE_CLASS}"

mas gitops-suite-app-config \
  --github-push \
  --mas-app-id  "manage" \
  --mas-app-kind "ManageApp" \
  --mas-appws-api-version "apps.mas.ibm.com/v1" \
  --mas-appws-kind "ManageWorkspace" \
  --mas-appws-spec-yaml "/demo-files/manage/manage-appws-spec.yaml" \
  --mas-app-server-bundles-combined-add-server-config-yaml "/demo-files/manage/manage-server-bundles.yaml"
```


![ArgoCD after Manage activated](docs/img002/05-inst8.png)


# Known Issues / Troubleshooting

If you change any values in secrets manager, you must hard-refresh the appropriate ArgoCD application in order for the updates to be picked up by ArgoCD
> TODO: screenshot


Cert deprovisioning steps will hang unless using ArgoCD 2.11.0 or later. If on ArgoCD <2.11, ensure the following steps are performed manually to avoid the problem:
> TODO




# Current Limitations

Only supports ROSA
Only supports on-cluster ArgoCD
Only supports Manage



# Removed (for now)
These `.yaml` configuration files are monitored by [Git Generators](https://argo-cd.readthedocs.io/en/stable/operator-manual/applicationset/Generators-Git/#git-generator-files) on the [Cluster Root Application Set](https://github.com/ibm-mas/gitops/blob/demo2/root-applications/ibm-mas-account-root/templates/000-cluster-appset.yaml) (installed by the **Account Root Application**), and the [MAS Instance Application Set](https://github.com/ibm-mas/gitops/blob/demo2/root-applications/ibm-mas-cluster-root/templates/099-instance-appset.yaml) (installed by the **Cluster Root Application**). The **Cluster Root Application** and **MAS Instance Root Application** Helm Charts contain templates that are conditionally enabled when the associated configuration is picked up the Application Sets. For instance, `ibm-operator-catalog.yaml` contains:
```yaml
ibm_operator_catalog:
    mas_catalog_version: xxx
    mas_catalog_image: xxx
```

When the associated Git generator on the [Cluster Root Application Set](https://github.com/ibm-mas/gitops/blob/demo2/root-applications/ibm-mas-account-root/templates/000-cluster-appset.yaml) picks up this file:
```yaml
- git:
    repoURL: "{{ .Values.generator.repo_url }}"
    revision: "{{ .Values.generator.revision }}"
    files:
    - path: "{{ .Values.account.id }}/*/ibm-operator-catalog.yaml"
```
It will be added to the Helm values used to render the [Cluster Root Application Helm Chart](https://github.com/ibm-mas/gitops/tree/demo2/root-applications/ibm-mas-cluster-root). This will result in condition at the top of the [000-ibm-operator-catalog-app](https://github.com/ibm-mas/gitops/blob/demo2/root-applications/ibm-mas-cluster-root/templates/000-ibm-operator-catalog-app.yaml) evaluating to true:
```
{{- if not (empty .Values.ibm_operator_catalog) }}
```
This will result in ArgoCD installing the IBM Operator Catalog Application, which in turn will deploy the resources in the [000-ibm-operator-catalog Helm Chart](https://github.com/ibm-mas/gitops/blob/demo2cluster-applications/000-ibm-operator-catalog) to the target cluster.
