# Scenario JumpServer Realtime (AWS)

This folder creates an AWS version of the JumpServer realtime scenario:
- 2 JumpServer app nodes behind an ALB
- 1 dedicated PostgreSQL + Redis node
- External DB/Redis configured via cloud-init

## Prerequisites

- Terraform >= 1.5
- An existing EC2 key pair
- AWS credentials configured in your environment

## Authentification AWS via variables d'environnement (recommandé)

Pour tester avec uniquement une `access key` et une `secret key`, exportez-les dans votre terminal avant d'exécuter Terraform. Ne collez jamais les valeurs dans le dépôt.

```bash
# Remplacez les valeurs par celles stockées dans votre gestionnaire de secrets
export AWS_ACCESS_KEY_ID=YOUR_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=YOUR_SECRET_ACCESS_KEY
# Région recommandée pour ces tests
export AWS_DEFAULT_REGION=eu-central-1
```

Vous pouvez ensuite utiliser les commandes Terraform ci‑dessous; le provider AWS utilisera automatiquement ces variables d'environnement.

## Deploy

```bash
cd /home/chaima/playsoft/terraform/scenario-jumpserver-realtime-aws
cp env/dev.tfvars.example env/dev.tfvars
# edit passwords and key name
terraform init
terraform plan -var-file=env/dev.tfvars
terraform apply -var-file=env/dev.tfvars
```

## Outputs

```bash
terraform output alb_dns_name
terraform output jumpserver_public_ips
terraform output data_node_public_ip
expliquer le code  qui terraform output dns_record_fqdn
```

## Optional Route53 DNS

To create a DNS record pointing to the ALB, set the following in your tfvars:

```hcl
create_dns_record = true
route53_zone_id   = "Z1234567890ABCDEFG"
dns_record_name   = "jump.example.com"
```

## IAM and S3 backup (optional)

This scenario can create an EC2 IAM role and use it for S3 backups from the data node.

```hcl
create_iam_role          = true
attach_ssm_policy        = true
attach_cloudwatch_policy = false

enable_s3_backup        = true
create_s3_backup_bucket = true
s3_backup_bucket_name   = "my-jumpserver-backup-bucket"
s3_backup_prefix        = "jumpserver/"
s3_backup_cron          = "0 * * * *"
```

## Notes

- This scenario uses a simple public subnet layout for quick testing.
- For production, add private subnets + NAT and restrict public exposure.
