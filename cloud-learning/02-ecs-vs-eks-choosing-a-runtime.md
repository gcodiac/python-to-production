# Lesson 02 — ECS vs EKS: Choosing a Runtime

**What you'll learn:** how this same application would run on AWS ECS, how that compares to EKS, and the honest reason this course chose the more complicated option.

## Goal

Be able to argue *both* sides of this decision, and recognise that "we use Kubernetes" is a trade-off rather than an achievement.

## The claim this lesson will not make

You will often see this said, and it is **wrong**:

> "ECS doesn't scale, that's why you need EKS."

ECS scales to very large production workloads. Plenty of substantial companies run entirely on ECS. Scale is not the differentiator.

## The accurate comparison

```text
ECS
├── simpler
├── AWS-native
├── less operational overhead
├── usually cheaper operationally
├── excellent for many small/medium services
├── Fargate removes worker-node management
└── can scale to substantial workloads

EKS
├── Kubernetes API/ecosystem
├── portable Kubernetes skills
├── Helm/operators/controllers
├── richer orchestration ecosystem
├── strong platform-engineering learning value
├── common organisational standard
├── easier conceptual portability across cloud/on-prem Kubernetes
└── significantly more complexity and operational responsibility
```

There is also a hard cost difference worth naming: **EKS charges $0.10/hour (~$73/month) for the control plane before you run a single Pod.** ECS charges nothing for the control plane — you pay only for the compute your tasks use.

## How this exact application would run on ECS

The application, image and database would not change at all. Only the runtime wrapper differs:

```text
ECR
 ↓
ECS Task Definition
 ↓
ECS Service
 ↓
Fargate Tasks
 ↓
ALB
 ↓
RDS
```

### The pieces

* **ECS cluster** — a logical grouping. With Fargate it holds no servers you manage; it is essentially a namespace for services.
* **Task definition** — the closest ECS analogue to a Pod spec: image (by digest), CPU/memory, port mappings, environment variables, secrets, and log configuration. Versioned as immutable revisions, so "deploy" means "point the service at a new revision".
* **Task** — one running instance of a task definition (analogous to a Pod).
* **Service** — keeps N tasks running and registers them with a load balancer target group (analogous to a Deployment + Service).
* **Fargate** — serverless compute for tasks: no EC2 instances, no node group, no AMI patching, no node IAM role. This is the single biggest operational simplification versus EKS with managed nodes.
* **EC2 launch type** — the alternative, where you *do* manage container instances. Comparable to EKS managed nodes in operational burden.

### The two IAM roles people confuse

* **Task execution role** — used by the ECS *agent*, before your code runs: pulling the image from ECR, fetching secrets, writing logs. Roughly analogous to the node's ability to pull images.
* **Task role** — the identity *your application code* uses to call AWS APIs. This is the direct analogue of the EKS Pod Identity role this course uses for the Notes Pod.

### Secrets

ECS integrates with Secrets Manager natively in the task definition:

```json
"secrets": [
  { "name": "DB_PASSWORD", "valueFrom": "arn:aws:secretsmanager:...:secret:...:password::" }
]
```

The agent fetches it and injects it as an environment variable. Notably this is *simpler* than the EKS path this course builds (Secrets Store CSI driver + SecretProviderClass + volume mount) — though injecting as an env var is arguably weaker than a mounted file, since env vars are visible to anything that can read the process environment.

### Load balancing and health

An ALB target group points at the tasks; the service registers/deregisters tasks automatically. Health checks are defined on the target group (`/health`) plus optionally a container `HEALTHCHECK`. There is no Ingress object and no controller to install — the ALB is created directly in Terraform.

### Rolling deployments

The ECS service does rolling deployments natively, controlled by `minimumHealthyPercent` / `maximumPercent` (conceptually equivalent to `maxUnavailable` / `maxSurge`). Circuit breaker configuration can auto-roll-back a failed deployment — something Kubernetes does not do for you without extra tooling.

### Autoscaling

Application Auto Scaling scales the service's task count on CloudWatch metrics (CPU, memory, ALB request count per target). Comparable to HPA, but without needing to install a metrics server.

### Logging and debugging

`awslogs` log driver ships container output to CloudWatch Logs with one configuration block. **ECS Exec** gives you an interactive shell into a running task (`aws ecs execute-command`), analogous to `kubectl exec`.

### Sketch of the Terraform (conceptual — not provisioned by this course)

```hcl
resource "aws_ecs_cluster" "this" { name = "notes-app-staging" }

resource "aws_ecs_task_definition" "app" {
  family                   = "notes-app"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.task_execution.arn   # pulls image, reads secret
  task_role_arn            = aws_iam_role.task.arn             # what the app itself may do

  container_definitions = jsonencode([{
    name  = "notes-app"
    image = "${aws_ecr_repository.app.repository_url}@sha256:..."   # digest, not a tag
    portMappings = [{ containerPort = 8000 }]
    environment  = [{ name = "APP_ENV", value = "staging" }]
    secrets      = [{ name = "DB_PASSWORD", valueFrom = "${aws_db_instance.this.master_user_secret[0].secret_arn}:password::" }]
    logConfiguration = { logDriver = "awslogs", options = { "awslogs-group" = "/ecs/notes-app" } }
  }])
}

resource "aws_ecs_service" "app" {
  name            = "notes-app"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.network.public_subnet_ids
    security_groups = [aws_security_group.app.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "notes-app"
    container_port   = 8000
  }
}
```

Compare that to what this course actually builds for EKS: a cluster, a node group, a launch template, four add-ons, access entries, two Pod Identity roles, two platform Helm releases, and an application Helm chart. **For this application, the ECS version is genuinely less work and less to go wrong.**

## So why does this course use EKS?

Because the objective is not only "run the Notes app". It is also:

* Kubernetes fundamentals (Pods, Deployments, Services, Ingress, namespaces, RBAC)
* Helm and chart authoring
* controllers and operators as a pattern
* workload identity and Kubernetes-native secrets integration
* skills that transfer to any Kubernetes, on any cloud or on-premises

If the goal were purely "ship this app on AWS at the lowest operational cost", ECS Fargate would be the recommendation.

## Questions for the learner

1. Name two things EKS charges for that ECS Fargate does not.
2. In ECS, which role fetches the image from ECR — the task role or the task execution role? Which one would your application code use to call S3?
3. This course mounts the database password as a *file* via the CSI driver, while the ECS sketch above injects it as an *environment variable*. Which is stronger, and why?
4. Under what circumstances would you genuinely recommend EKS over ECS for a real project? Try to answer without using the word "scale".

## Practical exercise

Write a one-paragraph recommendation, as if to a team lead, choosing a runtime for this Notes application in a real company with three engineers and no existing Kubernetes. Then write the opposite recommendation for a company with forty engineers already running Kubernetes on-premises. Both should be defensible.

## Recap

ECS and EKS are both credible; the differences are operational complexity, ecosystem, portability and control-plane cost — not scale. This course chose EKS for the learning, not because it is the better fit for this application. Next: the Kubernetes mental model you will need to make that choice pay off.
