#!/bin/bash

kind --version

if [ $(kind get clusters | grep -E 'kind') ]
then
  kind delete cluster --name kind
fi
kind create cluster --image kindest/node:v1.21.1 --config=k8s/cluster.yaml --wait 5m

kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v0.47.0/deploy/static/provider/kind/deploy.yaml

kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s

retry=60
code=1
last=""
until [[ $retry -le 0 || $code -eq 0 ]]
do
  result=$(kubectl apply -f k8s/router.yaml 2>/dev/null)
  code=$?

  if [[ "$result" != "$last" ]]
  then
    echo "$result"
  fi
  last=$result

  if [[ $code -eq 0 ]]
  then 
    exit $code
  fi

  ((retry--))
  echo waiting for nginx admission controller to start ...
  sleep 2
done

.scripts/k8s-nginx-dump.sh "timeout waiting for nginx admission controller to start"

exit $code