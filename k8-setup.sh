#!/usr/bin/env bash
# Configure local Kubernetes client, kubectl, to access local Vagrant Kubernetes.

: ${REPO:="~/repos/git/coreos-kubernetes/multi-node/vagrant"}
: ${CA:="${REPO}/ssl/ca.pem"}
: ${adminKey:="${REPO}/ssl/admin-key.pem"}
: ${IPADDR:="172.17.4.101"}
: ${TGT:="vagrant"}

cd ${REPO}
kubectl config set-cluster ${TGT} --server=https://${IPADDR}:443 --certificate-authority=${CA}
kubectl config set-credentials vagrant-admin --certificate-authority=${CA} --client-key=${adminKey} --client-certificate=${PWD}/ssl/admin.pem
kubectl config set-context ${TGT} --cluster=${TGT} --user=vagrant-admin
kubectl config use-context ${TGT}
