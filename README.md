# Maximo Application Suite GitOps Demo

## Steps
1. Provision an OCP Cluster
2. Install & Configure ArgoCD
3. Create the MAS root application
4. ...


### 1. Provision an OCP Cluster
```bash
EXPORT IBMCLOUD_APIKEY=xxx
mas provision-roks -r mas-development -c gitopsdemo -v 4.12_openshift --worker-count 3 --worker-flavor b3c.16x64.300gb --worker-zone lon02 --no-confirm
```

### 2. Install & Configure ArgoCD
```
```

### 3. Create the MAS root application

