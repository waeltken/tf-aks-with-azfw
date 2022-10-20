# vnet-peering

Vnet peering example with two virtual machines.

## How to use

Remove or set the azurerm backend.
Have an ssh public key ready.

```shell
terraform init
terraform apply

#ssh into vm1
ssh <20.160.55.18>

#ping vm2
ping <172.32.1.4>
```

