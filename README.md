# helm-local-k8s

## Description

Local k8s Helm Chart is all in one chart that needs to spin up all a demo setup with Backbase IPS and CX6 applications

## Diagram

![kubernetes](bb-local-kubernetes.png)

## Prerequisites

A Kubernetes cluster

### Docker for Desktop k8s

https://medium.com/p/kubernetes-in-local-the-easy-way-f8ef2b98be68?source=email-751ac5929c0e--writer.postDistributed&sk=1cf6c2f31d82d836a2a75503b2fb17be


Helm 2
```
brew install helm@2
```
Tiller
```
helm init
```
Nginx
```
kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-0.31.1/deploy/static/provider/cloud/deploy.yaml
```
## Adding Backbase Charts repo to local

Run `helm repo list` to check if `backbase-charts` is added to your local. If not add by running following command:
```
helm repo add backbase-charts https://repo.backbase.com/backbase-charts --username "$username" --password "$password"
helm repo update
```

## How to use

Update dependencies

```
helm dependency update local-k8s
```

## How to use
If you do not have the images locally please add `regcred` secret

```
kubectl create secret docker-registry regcred --docker-server=https://repo.backbase.com/backbase-docker-releases --docker-username=<your-username> --docker-password=<your-password> --docker-email=<your@email.com>
```
```
kubectl patch serviceaccount default -p "{\"imagePullSecrets\": [{\"name\": \"regcred\"}]}" -n default
```

Change `<yourRepoUsername>` and `<yourRepoPassword>` with your Repo credentials in values.yaml

## Install
```
helm install local-k8s --name=local-k8s --wait
```

## Verify
Open a browser and point to:
```
http://kubernetes.docker.internal/cxp-manager/login
```

## Configuration

All configuration is provided in values.yaml

## Changelog

- 0.0.1: Initial release
- 0.1.0: Update Edge 2 and Registry removed
- 0.1.2: Charts and App version update