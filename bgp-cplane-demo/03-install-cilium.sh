#!/bin/bash

VERSION="1.19.3"

helm upgrade --install --namespace kube-system --repo https://helm.cilium.io cilium cilium --values values.yaml --version ${VERSION}

#kubectl rollout restart daemonset cilium -n kube-system

#cilium status --wait
