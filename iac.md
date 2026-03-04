# IaC

```mermaid
flowchart LR
  A[Terraform: Yandex provider] --> B[Yandex VPC + subnets]
  B --> C[YaC]
  C --> D[Node group]
  D --> E[TF - k8s]
  E --> F[Ansible]
  F --> G[Deployment and Service]
```

# Terraform

* [main.tf](tf/main.tf)
* [variables.tf](tf/variables.tf)
* [outputs](tf/outputs.tf)

# Ansible

* [prep](ansible/prep.sh)
* [inventory](ansible/inventory.ini)
* [deployment playbook](ansible/deploy.yml)
* [run](ansible/run.sh)