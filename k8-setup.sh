#!/usr/bin/env bash
# Configure local Kubernetes client, kubectl, to access local Vagrant Kubernetes.

: ${K8_REPO:="~/repos/git/coreos-kubernetes/multi-node/vagrant"}
: ${K8_CA:="${K8_REPO}/ssl/ca.pem"}
: ${K8_ADMKEY:="${K8_REPO}/ssl/admin-key.pem"}
: ${K8_IPADDR:="172.17.4.101"}
: ${K8_PORT:=443}
: ${K8_TGT:="vagrant-multi"}

cd ${K8_REPO}
kubectl config set-cluster ${K8_TGT}-cluster --server=https://${K8_IPADDR}:${K8_PORT} --certificate-authority=${K8_CA}
kubectl config set-credentials ${K8_TGT}-admin --certificate-authority=${K8_CA} --client-key=${K8_ADMKEY} --client-certificate=${PWD}/ssl/admin.pem
kubectl config set-context ${K8_TGT} --cluster=${K8_TGT}-cluster --user=${K8_TGT}-admin
kubectl config use-context ${K8_TGT}
