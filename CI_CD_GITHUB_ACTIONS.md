# Guide CI/CD GitHub Actions

Ce projet utilise deux workflows GitHub Actions:

- `CI` pour valider Terraform, Ansible, YAML, secrets et IaC.
- `Deploy Terraform` pour faire un `plan` ou un `apply` manuel sur un stack Terraform.

## 1. Créer les secrets GitHub

Dans GitHub, allez dans `Settings` > `Secrets and variables` > `Actions` > `New repository secret`.

Ajoutez au minimum:

- `HCLOUD_TOKEN` pour Hetzner Cloud
- `AWS_ACCESS_KEY_ID` si vous déployez le stack AWS
- `AWS_SECRET_ACCESS_KEY` si vous déployez le stack AWS
- `AWS_SESSION_TOKEN` si vous utilisez des credentials temporaires AWS
- `AWS_DEFAULT_REGION` si vous déployez le stack AWS

Conseils:

- N’ajoutez jamais ces valeurs dans le dépôt Git.
- Gardez les fichiers locaux comme `env/dev.tfvars` hors de Git.
- Utilisez des secrets distincts si vous avez plusieurs environnements.

## 2. Créer un GitHub Environment

Dans GitHub, allez dans `Settings` > `Environments` > `New environment`.

Créez par exemple:

- `production`

Puis configurez:

- `Required reviewers` pour forcer une approbation avant `apply`
- `Environment secrets` si vous voulez isoler les secrets par environnement

Le workflow `Deploy Terraform` utilise le champ `environment` et attend ce nom.

## 3. Lancer le déploiement

Dans l’onglet `Actions` du dépôt:

1. Ouvrez `Deploy Terraform`.
2. Cliquez sur `Run workflow`.
3. Renseignez:
   - `stack_path` par exemple `terraform/jumpserver-ha`
   - `action` = `plan` ou `apply`
   - `environment` = `production`

Bon usage:

- Lancez d’abord `plan`.
- Vérifiez les changements proposés.
- Lancez `apply` seulement après validation.

## 4. Ce que fait le workflow CI

Le workflow `CI` s’exécute sur `push`, `pull_request` et manuellement.

Il vérifie:

- `terraform fmt -check`
- `terraform validate` sur tous les stacks sous `terraform/`
- `yamllint` sur `ansible/` et `terraform/ansible/`
- `ansible-lint`
- `gitleaks` pour les secrets
- `checkov` pour les règles IaC

## 5. Si vous utilisez GitLab plus tard

Je peux convertir ces workflows en `.gitlab-ci.yml` avec les mêmes étapes:

- validation
- scan de secrets
- scan IaC
- déploiement manuel avec approbation