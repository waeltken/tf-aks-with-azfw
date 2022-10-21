# Terraform example for AKS with Azure Firewall

Vnet peering example with two virtual machines.

## How to use

Remove or set the azurerm in `backend.tf`.
Remove or set the subscription_id in `provider.tf`.

```shell
terraform init
terraform apply

az aks get-credentials -g aks-with-azfw-rg -n aks-with-azfw

kubectl create deployment nginx --image=nginx
kubectl expose deployment nginx --port=80 --target-port=8000 --type=LoadBalancer
```
