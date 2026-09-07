# Lesson 17 — Costs, Production Trade-offs and Teardown

**What you'll learn:** what this environment actually costs, what production would do differently, and how to tear it down without orphaning billable resources.

## Goal

Be able to shut this environment down completely and confidently, and to explain every deliberate simplification.

## What this costs

Real prices, eu-west-1, verified via the AWS Pricing API where noted:

| Component | Rate | ~Monthly |
|---|---|---|
| EKS control plane | $0.10/hour | **$73.00** |
| EC2 worker (t3.medium ×1) | $0.0456/hour | **$33.29** |
| EBS gp3 root, 20 GiB | ~$0.084/GiB-month | ~$1.70 |
| RDS db.t4g.micro | $0.017/hour | **$12.41** |
| RDS gp3 storage, 20 GiB | ~$0.127/GiB-month | ~$2.54 |
| Application Load Balancer | $0.028/hour | **$20.44** + LCU |
| Public IPv4 ×3 | $0.005/hour each | ~$10.95 |
| Secrets Manager (1 secret) | $0.40/month | $0.40 |
| ECR + S3 state | usage-based | <$0.25 |

**≈ $155/month, or ~$0.21/hour.**

The uncomfortable part: **the EKS control plane bills from the moment the cluster exists**, whether or not a single Pod runs on it. An idle forgotten cluster is ~$2.40/day.

### What was deliberately not created

```text
NAT Gateway                  0     (~$35/month saved)
Multi-AZ RDS                 no    (roughly doubles instance cost)
Production environment       none  (would roughly double everything)
Managed Grafana/Prometheus   none  (Stage 5 self-hosts with Helm)
CloudWatch Container Insights no
EKS control-plane logging    off   (per-GB ingestion)
Performance Insights         off
Enhanced Monitoring          off
```

## Checking what is running

```bash
aws eks list-clusters --region eu-west-1
aws eks describe-nodegroup --cluster-name notes-app-staging \
  --nodegroup-name notes-app-staging-ng --region eu-west-1 \
  --query 'nodegroup.{type:instanceTypes,scaling:scalingConfig}'
aws rds describe-db-instances --region eu-west-1 \
  --query 'DBInstances[].{id:DBInstanceIdentifier,class:DBInstanceClass,multiaz:MultiAZ}'
aws elbv2 describe-load-balancers --region eu-west-1 --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-nat-gateways --region eu-west-1 --query 'NatGateways[].NatGatewayId'
aws ecr describe-repositories --region eu-west-1 --query 'repositories[].repositoryName'
```

## What production would change

Not implemented here — implementing them to look impressive would add cost without adding understanding:

```text
multiple worker nodes            multiple replicas + Pod anti-affinity
private worker subnets           NAT Gateway or VPC endpoints
Multi-AZ RDS                     dedicated least-privilege DB user
longer backup retention          deletion protection enabled
HTTPS via ACM + Route 53         private/restricted Kubernetes API endpoint
topology spread constraints      PodDisruptionBudget
HPA + Karpenter/cluster autoscaling
NetworkPolicy (with an enforcing CNI)
Security Groups for Pods
EKS control-plane audit logging
KMS envelope encryption for Kubernetes Secrets
customer-managed KMS key for Terraform state
```

## Teardown — order matters

**Do not run `terraform destroy` on the cluster first.** The ALB was created by the AWS Load Balancer Controller in response to an Ingress. If the cluster disappears first, nothing is left to delete that ALB, and it keeps billing as an orphan.

Correct order:

```bash
# 1. Application first - this removes the Ingress, which removes the ALB
helm uninstall notes-app -n notes-app

# 2. Confirm the ALB is actually gone before continuing
kubectl -n notes-app get ingress
aws elbv2 describe-load-balancers --region eu-west-1 \
  --query 'LoadBalancers[].LoadBalancerName'

# 3. Platform controllers
cd infra/platform/staging && terraform destroy

# 4. AWS infrastructure (EKS, RDS, VPC, IAM, ECR)
cd ../../environments/staging && terraform destroy
```

Terraform's dependency graph handles ordering *within* step 4. What it cannot know about is the ALB from step 1, because Terraform never created it — Kubernetes did.

### Verify nothing is orphaned

```bash
aws elbv2 describe-load-balancers --region eu-west-1 --query 'LoadBalancers[].LoadBalancerName'
aws ec2 describe-addresses --region eu-west-1 --query 'Addresses[].PublicIp'
aws ec2 describe-volumes --region eu-west-1 --filters Name=status,Values=available
```

### The state bucket

`infra/bootstrap` is destroyed **last and separately**, because it holds the state describing itself. To remove it entirely you must empty the versioned bucket first (including non-current versions), then delete it — or simply keep it, since an empty S3 bucket costs essentially nothing.

## Do not destroy yet

**Stage 5 reuses this cluster** for self-hosted Prometheus/Grafana. Destroying now means rebuilding (and re-waiting ~15 minutes) later. If you are pausing for more than a few days, the cost question is worth revisiting — but a partial teardown of just the node group saves only the EC2 charge, not the $73/month control plane.

## Questions for the learner

1. Why can Terraform not clean up the ALB for you?
2. What is the largest single cost here, and can it be reduced without deleting the cluster?
3. Why is the state bucket destroyed separately from everything else?

## Recap

This environment costs about $0.21/hour, dominated by the EKS control plane; teardown must delete the Kubernetes Ingress before the cluster to avoid an orphaned load balancer; and every production difference is documented rather than half-built.
