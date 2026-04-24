# GitOps with Cluster-Admin and Application-Admin Roles

This guide demonstrates an alternative approach to deploying MAS using GitOps with separated administrative responsibilities. This workflow splits the deployment into two phases:

1. **Cluster-level operations** using the `cluster-admin` role
2. **Application-level operations** using the `application-admin` role

This separation allows for better security boundaries and role-based access control in enterprise environments.

## Overview

The deployment process is divided into two distinct phases:

- **Phase 1: Cluster-Admin Role** - Installs cluster-wide infrastructure including ArgoCD, operators, and cluster-scoped resources
- **Phase 2: Application-Admin Role** - Deploys MAS instances and applications within restricted namespaces

### Phase 1 Deployment Options

For Phase 1 cluster-level operations, you have two options:

1. **Option 1: ArgoCD with cluster-admin role** - Use ArgoCD with `cluster_admin_role=true` to deploy cluster-level resources. This approach also automatically creates all necessary RBAC for Phase 2 via the [`600-application-admin-rbac`](https://github.com/ibm-mas/gitops/tree/main/instance-applications/600-application-admin-rbac) Helm chart. See [Phase 1](#phase-1-cluster-level-operations-cluster-admin-role-with-argocd) below for the guide.

2. **Option 2: Pre-install Repository** - Use the [ibm-mas/pre-install](https://github.com/ibm-mas/pre-install) repository with Kustomize to set up cluster-level resources. This offers a subset of cluster-level resources but is sufficient for most installations. **When using this option, you must manually configure RBAC** using the Kustomize configurations in the [`rbac/`](https://github.com/ibm-mas/gitops/tree/main/rbac) directory of the GitOps repository.

This guide focuses on **Option 1** (ArgoCD with cluster-admin role), which provides automatic RBAC configuration and a more complete set of cluster-level resources. For details on Option 2, see the [ibm-mas/pre-install](https://github.com/ibm-mas/pre-install) repository and the [RBAC README](https://github.com/ibm-mas/gitops/blob/main/rbac/README.md) in the GitOps repository.

When either option is complete you would then move to [Phase 2](#phase-2-application-level-operations-application-admin-role) for the applicaiton admin level deployment

## Prerequisites

All prerequisites from the [main README](../README.md#prerequisites) apply. Additionally, you will need:

- Appropriate RBAC permissions to create and manage cluster-level resources (for Phase 1)
- A separate ArgoCD instance or namespace for application-level deployments (for Phase 2)

## Phase 1: Cluster-Level Operations (cluster-admin role) with ArgoCD

### Setup Environment Variables

Set the same environment variables as defined in the main guide:

```bash
# This will determine the name of the top-level folder in your Config Repository
# It will also be provided in the configuration of the Account Root Application
export ACCOUNT_ID="dev"

# This will determine second-level folder in your Config Repository.
# It will also be included in the names of the Applications that ArgoCD will generate
# Must be less than 15 characters (see "Naming Length Restrictions" below)
export CLUSTER_ID="masdemo1"

# This will determine the OCP cluster that ArgoCD targets.
# In this guide, we are deploying a single MAS instance in the same cluster as ArgoCD.
export CLUSTER_URL="https://kubernetes.default.svc"

# This will determine third-level folder in your Config Repository.
# It will also be included in the names of the Applications that ArgoCD will generate
# Must be less than 15 characters (see "Naming Length Restrictions" below)
export MAS_INSTANCE_ID="inst1"

# This will determine the ID and name of the MAS Suite and Application workspace in your deployment
export MAS_WORKSPACE_ID="inst1ws1"
export MAS_WORKSPACE_NAME="Instance 1 Workspace 1"

# Details for access your AWS account and linked Redhat account.
# These will be used to provision the ROSA cluster and create a DocumentDB instance
export AWS_ACCESS_KEY_ID="xxx"
export AWS_SECRET_ACCESS_KEY="xxx"
export AWS_REGION="us-east-1"
export ROSA_TOKEN=xxx

# These will be used to configure the AVP plugin in ArgoCD so it is capable of retrieving secrets from AWS Secrets Manager
# They will also be used to configure various secrets automatically by some of the CLI functions we are about to call
# These can be the same as the AWS details above
export SM_AWS_REGION="${AWS_REGION}"
export SM_AWS_SECRET_ACCESS_KEY="${AWS_SECRET_ACCESS_KEY}"
export SM_AWS_ACCESS_KEY_ID="${AWS_ACCESS_KEY_ID}"

# This will be substituted into generated configuration .yaml files to reference secrets
# and allow them to be resolved by the AVP plugin when rendering Helm Charts
SM_AWS_ACCOUNT_ID="xxxxx"
export SECRETS_PATH="arn:aws:secretsmanager:${SM_AWS_REGION}:${SM_AWS_ACCOUNT_ID}:secret"
```

> **Naming Length Restrictions** Because we stitch together the different IDs that form the hierarchy together we need to ensure that the total length is less than the 64 character limit of ArgoCD applications, to achieve this follow these restrictions when setting values for `--cluster-id` (`CLUSTER_ID`), and `--mas-instance-id` (`MAS_INSTANCE_ID`):
> - **Cluster ID**: 15 characters. Must be unique within an account.
> - **MAS instance ID**: 15 characters. Must be unique within a cluster.

## Provision a ROSA Cluster
```bash
mas gitops-rosa -c "${CLUSTER_ID}" --ocp-version 4.14.18 --rosa-compute-machine-type m5.4xlarge --rosa-compute-nodes 3
```

## Login to your ROSA Cluster
```yaml
# Obtain the credentials generated for your ROSA cluster
# These are held in a YAML file generated by the gitops-rosa command
ROSA_CLUSTER_DETAILS_YAML="/mascli/tmp-rosa/rosa-${CLUSTER_ID}-details.yaml"
ROSA_CLUSTER_API_URL="$(cat ${ROSA_CLUSTER_DETAILS_YAML} | /usr/bin/yq .data.api_url)"
ROSA_CLUSTER_ADMIN_USERNAME="$(cat ${ROSA_CLUSTER_DETAILS_YAML} | /usr/bin/yq .data.username)"
ROSA_CLUSTER_ADMIN_PASSWORD="$(cat ${ROSA_CLUSTER_DETAILS_YAML} | /usr/bin/yq .data.admin_password)"

# And login to the cluster
oc login "${ROSA_CLUSTER_API_URL}" --username "${ROSA_CLUSTER_ADMIN_USERNAME}" --password "${ROSA_CLUSTER_ADMIN_PASSWORD}" --insecure-skip-tls-verify
```

> [!IMPORTANT]
> Note down these details in a secure location outside of the container so that you can easily recover them in the event that the container is lost.


## Setup your Cluster Admin role Config Git Repo

You will need to set up your own **Config Repository** in your preferred provider and supply its details to the CLI via some environment variables. This is where the cluster admin roles ArgoCD will look for configuration files that define your MAS instance, and it is where the CLI will push configuration files to.

Once you have setup the repository, in your MAS cli terminal session, run the following, replacing the values as appropriate.

```bash
export GITHUB_HOST="github.com"
export GITHUB_ORG="my-org"
export GITHUB_REPO="my-mas-gitops-repo"
export GIT_BRANCH="cluster-role"
export GIT_SSH="false"
```

Create a personal access token in your git provider, ensuring that it has sufficient permissions to read from and write to your **Config Repository**. Set it in your MAS cli terminal session environment as follows:
```bash
export GITHUB_PAT="xxx"
```

And configure git:
```bash
git config --global user.email "you@example.com"
```

### Bootstrap ArgoCD with Cluster-Admin Role

Bootstrap ArgoCD with cluster-admin privileges enabled, the `mas gitops-bootstrap` function will perform the following actions:
- Install ArgoCD operator
- Create ArgoCD instance
- Configure Secret Manager backend for ArgoCD
- Configure ArgoCD ServiceAccount and RBAC
- Enable the ArgoCD Vault plugin
- Configure ArgoCD authentication to your Cluster Admin roles **Config Repository** using ${GITHUB_PAT}
- Add `cluster-admin` access to openshift-gitops ServiceAccount (required for managing SecurityContextConstraints)
- Create an ArgoCD project for Maximo Application Suite
- Create the Maximo Application Suite **Account Root Application** with `cluster_admin_role` set to true, and `application_admin_role` set to false.

```bash
mas gitops-bootstrap \
  --account-id "${ACCOUNT_ID}" \
  --app-revision "7.5.0" \
  --sm-aws-secret-region "${SM_AWS_REGION}" \
  --sm-aws-secret-key "${SM_AWS_SECRET_ACCESS_KEY}" \
  --sm-aws-access-key "${SM_AWS_ACCESS_KEY_ID}" \
  --github-url "https://${GITHUB_HOST}/${GITHUB_ORG}/${GITHUB_REPO}" \
  --github-revision "${GIT_BRANCH}" \
  --github-pat "${GITHUB_PAT}" \
  --cluster-admin-role true \
  --application-admin-role false
```

### Install Cluster-Level Components

#### Operator Catalog and Certificate Manager

```bash
ICR_USERNAME="xxx"
ICR_PASSWORD="xxx"

mas gitops-cluster \
  --github-push \
  --cluster-url "${CLUSTER_URL}" \
  --icr-username "${ICR_USERNAME}" \
  --icr-password "${ICR_PASSWORD}" \
  --catalog-version v9-260129-amd64 \
  --catalog-image icr.io/cpopen/ibm-maximo-operator-catalog
```

#### IBM Data Reporter Operator

```bash
mas gitops-dro --github-push
```

#### DB2U Operator

```bash
mas gitops-db2u \
  --github-push \
  --db2-channel v110509.0
```

#### MAS Suite (Cluster-Level)

The `--argocluster-instance` parameter here is the name of the ArgoCD instance that is used for the application admin in Phase 2. The reason for it being provided here is so the generated namespaces and argo applications that the cluster level admin role creates can be labeled so that the application level ArgoCD instance can also manage resources in that namespace.

```bash
mas gitops-suite \
  --mas-channel 9.1.x \
  --github-push \
  --mas-instance-id "${MAS_INSTANCE_ID}" \
  --argocluster-instance mas-argocd
```

#### Install MAS Applications (Cluster-Level)

For each application you want to install, run the appropriate command with the `--cluster-admin-role` flag:

**Visual Inspection:**
```bash
mas gitops-suite-app-install \
  --mas-instance-id "${MAS_INSTANCE_ID}" \
  --mas-app-id visualinspection \
  --mas-app-channel 9.1.x \
  --mas-app-catalog-source ibm-operator-catalog \
  --mas-app-api-version apps.mas.ibm.com/v1 \
  --mas-app-kind VisualInspectionApp \
  --github-push \
  --cluster-admin-role
```

**Manage:**
```bash
mas gitops-suite-app-install \
  --mas-instance-id "${MAS_INSTANCE_ID}" \
  --mas-app-id manage \
  --mas-app-channel 9.1.x \
  --mas-app-catalog-source ibm-operator-catalog \
  --mas-app-api-version apps.mas.ibm.com/v1 \
  --mas-app-kind ManageApp \
  --github-push \
  --cluster-admin-role
```

> This commands will not install the MAS applications, but will create the namespaces and install the operators and subscription ready for the application deployment in Phase 2 by the application admin.


### RBAC Configuration

When using **Option 1** (ArgoCD with cluster-admin role), the RBAC configuration is automatically created and applied via the `application-rbac` ArgoCD application. This works dynamically even when new applications are added later, eliminating the need for manual RBAC generation and application.

> **Note**: If you chose **Option 2** (pre-install repository) for Phase 1, you must manually configure RBAC using the Kustomize configurations. See the [RBAC README](https://github.com/ibm-mas/gitops/blob/main/rbac/README.md) for detailed instructions on generating and applying namespace-scoped RBAC using the `generate_rbac_overlays.py` script.

## Phase 2: Application-Level Operations (application-admin role)

### Update Environment Variables

Switch to application-admin roles **Config Respoitory** by updating the Git branch. If the application admin is expected to use a different giithub repo/org or git provider then update those other variables as well:

```bash
export GIT_BRANCH="application-role"
export GITHUB_HOST="github.com"
export GITHUB_ORG="my-org"
export GITHUB_REPO="my-mas-gitops-repo"
```

### Bootstrap ArgoCD for Application-Admin

Bootstrap a restricted ArgoCD with application-admin privileges enabled, the `mas gitops-bootstrap` function will perform the following actions:
- Install ArgoCD operator (if not aleady installed)
- Create ArgoCD instance in the namespace defined by the value of `--argocluster-namespace`
- Configure Secret Manager backend for ArgoCD
- Configure ArgoCD ServiceAccount and RBAC that does not allow any cluster level access.
- Enable the ArgoCD Vault plugin
- Configure ArgoCD authentication to your roles **Config Repository** using ${GITHUB_PAT}
- Create an ArgoCD project for Maximo Application Suite
- Create the Maximo Application Suite **Account Root Application** with `cluster_admin_role` set to false, and `application_admin_role` set to true.

```bash
mas gitops-bootstrap \
  --account-id "${ACCOUNT_ID}" \
  --app-revision "7.5.0" \
  --github-url "https://${GITHUB_HOST}/${GITHUB_ORG}/${GITHUB_REPO}" \
  --github-revision "${GIT_BRANCH}" \
  --github-pat "${GITHUB_PAT}" \
  --cluster-admin-role false \
  --application-admin-role true \
  --restricted-access \
  --argoapp-namespace mas-argocd \
  --argocluster-namespace mas-argocd
```

### Configure Application-Level Components

#### Cluster Configuration

This will ensure that the cluster root applicationset is created in the argocd instance being used by the application admin, but no cluster level applications will be installed. This is solely to ensure that the instance applicationset is created from the cluster applicationset.

```bash
mas gitops-cluster \
  --github-push \
  --application-admin-role
```

#### Instance Configuration

At this point you can continue following the standard deployment guide from the [DRO](../README.md#generate-configuration-for-ibm-data-reporter-operator) section onwards. The commands are the same as the standard deployment guide, but as the root application already has the `application-admin-role` set to true, and `cluster-admin-role` set to false, then the helm charts will render the correct resources.

## Key Differences from Standard Deployment

### Cluster-Admin Phase
- Uses `--cluster-admin-role true` and `--application-admin-role false` flags
- Installs cluster-wide operators and infrastructure
- Creates RBAC automatically via ArgoCD application
- Deploys application operators at cluster level

### Application-Admin Phase
- Uses `--cluster-admin-role false` and `--application-admin-role true` flags
- Requires `--restricted-access` flag during bootstrap to only install non-cluster wide RBAC 
- Operates within specific namespaces (`--argoapp-namespace` and `--argocluster-namespace`)
- Uses different Git branch for the **Config Repository**
- Focuses on instance and application configuration

## Security Considerations

- **Separation of Concerns**: Cluster-level infrastructure is managed separately from application deployments
- **Namespace Isolation**: Application-admin operations are restricted to specific namespaces
- **RBAC Enforcement**: Automatic RBAC configuration ensures proper access controls
- **Git Branch Separation**: Different branches (or repo/org) for cluster and application configurations prevent accidental cross-contamination

## Troubleshooting

### RBAC Issues
If you encounter permission errors during application-admin operations:
1. Verify the `application-rbac` ArgoCD application is healthy in the cluster-admin ArgoCD instance
2. Check that the service account has the correct role bindings
3. Ensure namespaces were created during the cluster-admin phase

### ArgoCD Instance Conflicts
If applications don't appear in the correct ArgoCD instance:
1. Verify you're using the correct `--argocluster-namespace` parameter
2. Check that the Git branch matches the expected configuration
3. Ensure the `--restricted-access` flag was used during application-admin bootstrap

### Cross-Phase Dependencies
Some operations require resources from both phases:
1. Ensure cluster-admin phase is complete before starting application-admin phase
2. Verify all cluster-level operators are healthy
3. Check that secrets in AWS Secrets Manager are accessible from both contexts

## Additional Resources

- [Main GitOps Guide](../README.md) - Standard single-role deployment approach
- [MAS GitOps Documentation](https://ibm-mas.github.io/gitops/7.5/) - Comprehensive GitOps reference
- [RBAC Configuration Guide](https://github.com/ibm-mas/gitops/blob/main/rbac/README.md) - Detailed RBAC setup for application-admin role (required when using pre-install repository)
- [Pre-install Repository](https://github.com/ibm-mas/pre-install) - Alternative approach for cluster-level prerequisites
- [Locking Mechanisms](https://ibm-mas.github.io/gitops/configuration/locking-mechanisms/) - Understanding Git locking in GitOps commands