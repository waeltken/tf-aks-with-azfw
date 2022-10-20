# Terraform example for AKS with Azure Firewall

Vnet peering example with two virtual machines.

## How to use

Remove or set the azurerm in `backend.tf`.
Remove or set the subscription_id in `provider.tf`.

```shell
terraform init
terraform apply

az aks get-credentials -g aks-with-azfw-rg -n aks-with-azfw

helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace
```
