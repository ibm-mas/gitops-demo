# Maximo Application Suite GitOps Demo

## Overview

During bootstrap we create the **[Account Root Application](https://github.com/ibm-mas/gitops/tree/demo1/root-applications/ibm-mas-account-root)**, this installs the **[Cluster Root Application Set](https://github.com/ibm-mas/gitops/tree/demo1/root-applications/ibm-mas-cluster-root)**.

The **Cluster Root Application Set**  generates a **[Cluster Root Application](https://github.com/ibm-mas/gitops/tree/demo1/root-applications/ibm-mas-cluster-root)** for each cluster in the account. This contains the following Applications:
- [Operator Catalog](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/ibm-operator-catalog-app.yaml)
- [Common Services](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/ibm-operator-common-services-app.yaml)
- [DRO](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/ibm-dro-app.yaml)
- [Db2u](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/ibm-db2u-app.yaml)
- [CIS Compliance](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/cis-compliance-app.yaml)

The **Cluster Root Application Set** also contains the **MAS Instance Application Set**
- [MAS Instance](https://github.com/ibm-mas/gitops/blob/demo1/root-applications/ibm-mas-cluster-root/templates/instance-appset.yaml)

The **MAS Instance Application Set** contains .... <WORK IN PROGRESS> I haven't got this far yet


## GitOps with the MAS CLI
We have automated the steps to install MAS via GitOps, you do not need to use the CLI, but the same basic process must be followed.

### 1. Provision an OCP Cluster
```bash
export IBMCLOUD_APIKEY=xxx
mas provision-roks -r mas-development -c gitopsdemo -v 4.12_openshift --worker-count 3 --worker-flavor b3c.16x64.300gb --worker-zone lon02 --no-confirm
```

### 2. Setup Secrets Manager
Set up [AWS Secrets Manager](https://us-east-2.console.aws.amazon.com/secretsmanager/listsecrets?region=us-east-2), and [create an access key](https://us-east-1.console.aws.amazon.com/iam/home#/security_credentials?section=IAM_credentials)


### 2. Bootstrap ArgoCD and create the Account Root Application
- Install ArgoCD operator
- Create ArgoCD instance
- Configure Secret Manager backend for ArgoCD
- Configure ArgoCD ServiceAccount and RBAC
- Enable the ArgoCD Vault plugin
- Configure ArgoCD authentication to your application repository using personal access token
- Patch `openshift-marketplace` and `kube-system` namespaces to allow ArgoCD to manage them
- Add `cluster-admin` access to openshift-gitops ServiceAccount (required for managing CecurityContextContraints)
- Create an ArgoCD project for Maximo Application Suite
- Create the Maximo Application Suite **Account Root Application**

```bash
SECRET_KEY=xxx
ACCESS_KEY=xxx
PAT=xxx

mas gitops-bootstrap \
  --account-id demo \
  --cluster-id d1 \
  --app-revision demo1 \
  --sm-aws-secret-region us-east-2 \
  --sm-aws-secret-key $SECRET_KEY \
  --sm-aws-access-key $ACCESS_KEY \
  --github-url https://github.com/ibm-mas/gitops-demo \
  --github-revision 001 \
  --github-pat $PAT
```
You will end up with the root application and a single ApplicationSet deployed in ArgoCD as below:
![ArgoCD post-bootstrap](docs/img/01-bootstrap.png)

### 2. Generate configuration for the Cluster Root Application
- Create a new secret in AWS Secrets Manager `demo/demo1/ibm_entitlement` holding the image pull secret for the IBM Container Registry (which contains your IBM entitlement key)
- Create a new secret in AWS Secrets Manager `demo/demo1/aws` holding the access token and secret token for AWS Secrets Manager, which is used by various ArgoCD sync hooks to make updates to secrets
- Generate three new configuration files in the GitHub working directory:
    - [/demo/us-east-2/demo1/ibm-common-services.yaml](/demo/us-east-2/demo1/ibm-common-services.yaml)
    - [/demo/us-east-2/demo1/ibm-mas-cluster-base.yaml](/demo/us-east-2/demo1/ibm-mas-cluster-base.yaml)
    - [/demo/us-east-2/demo1/ibm-operator-catalog.yaml](/demo/us-east-2/demo1/ibm-operator-catalog.yaml)

```bash
USERNAME=xxx
PASSWORD=xxx
SECRET_KEY=xxx
ACCESS_KEY=xxx
SM_PATH=xxx

mas gitops-cluster -d /home/david/ibm-mas/gitops-demo \
  --account-id demo \
  --cluster-id demo1 \
  --icr-username $USER \
  --icr-password $PASSWORD \
  --sm-aws-secret-region us-east-2 \
  --sm-aws-secret-key $SECRET_KEY \
  --sm-aws-access-key $ACCESS_KEY \
  --secrets-path $SM_PATH \
  --catalog-version v8-240130-amd64 \
  --catalog-image icr.io/cpopen/ibm-maximo-operator-catalog \
  --catalog-action install \
  --common-services-channel v3.23 \
  --common-services-action install
```

You must now push these changes to the branch specified when you bootstrapped ArgoCD (in this case `001`), as soon as you do this you will see three new applications generated in ArgoCD as below:

![ArgoCD post-cluster](docs/img/02-cluster1.png)

The IBM Common Services and Operator Catalog applications will be visible as childen of the cluster application set

![ArgoCD post-cluster](docs/img/02-cluster2.png)

The Common Services application will take a little longer to syncronize because it first waits for the Operator Catalog to be ready before installing IBM Common Services from that catalog.

![ArgoCD after reconcile](docs/img/02-cluster3.png)


## Useful Commands

### Secrets Manager: List All Secrets
```bash
aws secretsmanager list-secrets --output yaml --no-cli-pager | yq -r '.SecretList[].Name' | grep "^demo/demo1"
```
