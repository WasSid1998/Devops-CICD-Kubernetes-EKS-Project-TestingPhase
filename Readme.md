---
PYTHON APP CI/CD – PRODUCTION ARCHITECTURE  
---

We have implemented a complete CI/CD pipeline for a Python application deployed on AWS using Terraform, Kubernetes (EKS), Jenkins, and supporting AWS services.  

High-Level Architecture Flow  

The request flow is as follows:  

User → Route53 → CloudFront → ALB (EKS Ingress) → EKS Pods → RDS → Response  
---
Flow Explanation:  
---
The user accesses the application URL.  
The request first hits Route53, which routes traffic to CloudFront.  
CloudFront forwards the request to the Application Load Balancer (ALB) created by Kubernetes Ingress.  
ALB routes traffic to EKS Pods running the Python application.  
The application communicates with RDS (database) located in a private subnet.  
Response is returned back to the user.  




---
Infrastructure Design  
---

AWS Components Used:  

VPC (with Public & Private Subnets)  
EKS Cluster (Application Runtime)  
RDS (Database Layer in Private Subnet)  
CloudFront (CDN Layer)  
Route53 (DNS Management)  
CloudWatch (Monitoring & Logging)  
IAM (Security & Access Control)  

Network Design:  

EKS Worker Nodes → Private Subnets  
RDS Database → Private Subnets  
ALB (Ingress Controller) → Public Subnet  
All components are interconnected securely inside the VPC  
Only controlled external access is allowed via CloudFront + ALB  




---
Project Folder Structure  
---

```text
myproject/
├── app/
│   ├── app.py
│   └── Dockerfile
│
├── jenkinsfile
│
├── terraform/
│   ├── bootstrap/
│   │   └── main.tf
│   │
│   ├── envs/
│   │   ├── dev/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars
│   │   ├── preprod/
│   │   │   ├── main.tf
│   │   │   └── terraform.tfvars
│   │   └── prod/
│   │       ├── main.tf
│   │       └── terraform.tfvars
│   │
│   ├── modules/
│   │   ├── vpc/
│   │   │   └── main.tf
│   │   ├── eks/
│   │   │   └── main.tf
│   │   ├── rds/
│   │   │   └── main.tf
│   │   ├── cloudfront/
│   │   │   └── main.tf
│   │   ├── cloudwatch/
│   │   │   └── main.tf
│   │   ├── iam/
│   │   │   └── main.tf
│   │   └── jenkins/
│   │       └── main.tf
│   │
│   └── k8s/
│       ├── base/
│       │   ├── deployment.yaml
│       │   └── hpa.yaml
│       │
│       └── overlays/
│           ├── dev/
│           │   ├── ingress.yaml
│           │   └── kustomization.yaml
│           ├── preprod/
│           │   ├── ingress.yaml
│           │   └── kustomization.yaml
│           └── prod/
│               ├── ingress.yaml
│               └── kustomization.yaml
```




---
CI/CD Pipeline Workflow (Jenkins)  
---
Jenkins is hosted on a public EC2 instance inside the same VPC  
Access restricted using specific IP rules defined in dev/main.tf  
GitHub webhook triggers Jenkins pipeline on every code push  

---
Pipeline Flow:  
---

Code pushed to GitHub  
Jenkins webhook triggers pipeline  
Build → Test → Docker Image creation  
Push image to registry  
Deploy to Dev environment  
If successful → Move to Preprod (QA) (Approval required)  
If approved → Move to Prod (Approval required)  



---
Multi-Environment Strategy  
---
We maintain three isolated environments:  

Dev  
Preprod (QA)  
Prod  

Each environment has:  

Separate Terraform configurations  
Separate state management  
Independent infrastructure  
Controlled promotion flow  





---
Deployment Steps  
---
Step 1: Bootstrap Infrastructure (State Management)  
---
cd terraform/bootstrap  
terraform init  
terraform plan  
terraform apply  

Creates:  
S3 Bucket (Terraform state storage)  
DynamoDB Table (State locking)  
---
Step 2: Deploy Dev Environment  
---
cd terraform/envs/dev  
terraform init  
terraform plan -var-file="terraform.tfvars"  
terraform apply -var-file="terraform.tfvars"  
---
Step 3: Deploy Preprod & Prod  
---
cd terraform/envs/preprod  
terraform init  
terraform plan -var-file="terraform.tfvars"  
terraform apply -var-file="terraform.tfvars"  

cd terraform/envs/prod  
terraform init  
terraform plan -var-file="terraform.tfvars"  
terraform apply -var-file="terraform.tfvars"  
---
Step 4: Configure kubectl Access  
---
aws eks update-kubeconfig --region us-east-1 --name pythonapp-dev  
aws eks update-kubeconfig --region us-east-1 --name pythonapp-preprod  
aws eks update-kubeconfig --region us-east-1 --name pythonapp-prod  
---
Step 5: Install AWS Load Balancer Controller  
---
Required for Ingress (ALB provisioning):  

for CLUSTER in pythonapp-dev pythonapp-preprod pythonapp-prod; do
  aws eks update-kubeconfig --region us-east-1 --name $CLUSTER
  
  helm repo add eks https://aws.github.io/eks-charts
  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n kube-system \
    --set clusterName=$CLUSTER
done  
---
Step 6: HPA metrics deployment  
---
for CLUSTER in myapp-dev myapp-preprod myapp-prod; do
  aws eks update-kubeconfig --region us-east-1 --name $CLUSTER
  kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
done  

kubectl get deployment metrics-server -n kube-system
---
Step 7: Deploy Kubernetes Manifests  
---
aws eks update-kubeconfig --region us-east-1 --name pythonapp-dev  
kubectl apply -k k8s/overlays/dev  

aws eks update-kubeconfig --region us-east-1 --name pythonapp-preprod  
kubectl apply -k k8s/overlays/preprod  

aws eks update-kubeconfig --region us-east-1 --name pythonapp-prod  
kubectl apply -k k8s/overlays/prod  


---
KeyFeatures  
---
Production-Grade Features Implemented  
High Availability  
EKS ensures auto-recovery of failed pods  
Zero downtime deployments supported  

---
Security  
---

S3 state locked using DynamoDB  
Private subnets for EKS & RDS  
Controlled Jenkins access via IP restriction  
---
Observability  
---
CloudWatch integrated for logs & metrics  
Alerts for application or database failures  

---
Database Resilience  
---
RDS deployed in Multi-AZ configuration  
Automatic failover in case of AZ failure  

---
Safe Deployments  
---
Jenkins includes rollback strategy  
Failed deployments automatically trigger rollback  
