### Installation process for EKS

There are a few tools that allow you to get up and running quickly on EKS. Cloudformation, Terraform, and eksctl are all good options, with eksctl probably being the quickest way to get started. I will be using Terraform since we are planning on plugging it intop our pipeline already. Terraform provides a nice tutorial and sample code repository to help you create all the necessary AWS services to run EKS. Their sample code is a good starting place and you can easily modify it to better suit your AWS environment.

#### What You'll Need

Before you get started, you'll need a few tools installed. Terraform is a tool to create, change, and improve infrastructure.

  - [terraform](https://www.terraform.io/downloads.html)
  - [helm](https://matthewpalmerw.net/kubernetes-app-developer/articles/how-to-install-helm-mac.html)
  - [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
  - [aws-vault](https://github.com/99designs/aws-vault)


  Table of Contents  <!-- omit in toc -->
 - [Introduction](#introduction)
 - [Simple Server Versions](#simple-server-versions)
 - [Simple Server Clojure Docker Image](#simple-server-clojure-docker-image)
 - [AWS Infrastructure](#aws-infrastructure)
   - [Terraform State](#terraform-state)
   - [Terraform Project Structure](#terraform-project-structure)
   - [AWS Resources](#aws-resources)
     - [DynamoDB Tables](#dynamodb-tables)
     - [VPC and Subnets](#vpc-and-subnets)
     - [EKS](#eks)
     - [ECR](#ecr)
 - [Using Terraform to Create the AWS EKS Infrastructure](#using-terraform-to-create-the-aws-eks-infrastructure)
 - [Connecting to AWS EKS.](#connecting-to-aws-eks)
 - [Debugging Why the First Attempt to Create EKS Failed](#debugging-why-the-first-attempt-to-create-eks-failed)
 - [Observations](#observations)
 - [Links to External Documentation](#links-to-external-documentation)


#### Simple Server Versions

I have three Simple Server Clojure versions (in the same application - versions implemented using Clojure profiles and some Clojure dispatching mechanisms):

- **single-node**: Statefull application in which all databases are implemented internally in the application. Basically a simple testing version since you can run the application without any external (database) dependencies.
- **table-storage**: A stateless production version for Azure environment in which the application uses Azure Table Storage as database. This work has been documented in the blog posts I told about in the Introduction chapter.
- **aws-dynamodb**: A stateless production version for AWS environment in which the application uses AWS DynamoDB as database. In this new project I'm creating AWS infra for this application version. There is also a "local-dynamodb" version which uses local dynamodb emulator as a database.

The Simple Server Clojure project is in my [Github account](https://github.com/gabelbombe/clojure/tree/master/clj-ring-cljs-reagent-demo/simple-server)


#### Simple Server Clojure Docker Image

You can find the [The Simple Server Clojure Docker Image Configuration](https://github.com/gabelbombe/docker/tree/master/demo-images/simple-server/clojure) in my Github account. In the Gihub repository you can find build scripts for building the Docker images used in the Kubernetes deployment for various Kubernetes clusters.


### AWS Infrastructure

I'm using Terraform to create the needed AWS infrastructure.

### Terraform State

For storing the Terraform state I'm using [S3](https://aws.amazon.com/s3/) [terraform backend](https://www.terraform.io/docs/backends/). See [env.tf](https://github.com/gabelbombe/aws/blob/master/terraform-eks/terraform/envs/dev/env.tf) how to configure a Terraform backend. Basically there is no need to configure a backend in a single-user project but let's do it professionally to demonstrate Terraform best practices as well.

### Terraform Project Structure

I'm using a Terraform structure in which I have environments ([envs](https://github.com/gabelbombe/aws/tree/master/terraform-eks/terraform/envs)) and [modules](https://github.com/gabelbombe/aws/tree/master/terraform-eks/terraform/modules). Environments define the environments and they reuse the entities defined in the modules directory. Environment basically just injects the environment related variables to [env-def](https://github.com/gabelbombe/aws/tree/master/terraform-eks/terraform/modules/env-def) which defines the actual modules to build the cloud infra.

### AWS Resources

#### DynamoDB Tables

I created module [dynamodb-tables](https://github.com/gabelbombe/aws/tree/master/terraform-eks/terraform/modules/dynamodb-tables) to isolate the creation of the needed DynamoDB tables. This module uses module [dynamodb](https://github.com/gabelbombe/aws/tree/master/terraform-eks/terraform/modules/dynamodb) to create all other tables except the product table which is a bit different with its global index and is therefore created separately.

#### VPC and Subnets

It was a bit of a suprise that you need that much VPC stuff (compared to Azure side). Possibly you necessarily don't need all these VPCs and subnets (if you just want to use the default VPC) but I thought it is better to stick with the working example as much as possible. I downgraded the VPC address space from the exampe - I thought that 65.000 addresses for a Kubernetes cluster is a bit of an overkill.

#### EKS

I was a bit surprised how much infra code there is using Terraform's [AWS EKS Introduction](https://learn.hashicorp.com/terraform/aws/eks-intro). I mainly used the example provided in [eks-cluster.tf](https://github.com/terraform-providers/terraform-provider-aws/blob/master/examples/eks-getting-started/eks-cluster.tf) with some of my own conventions.

Because there was quite a lot of infra code I also managed to screw the infra a bit. So, if you are using that example as your baseline read very carefully all tags, security group references, why cluster name is defined first etc. You can read about my tumbling in chapter "Debugging Why the First Attempt to Create EKS Failed" below.


#### ECR

Elastic Container Registry is needed to host the Docker images that Kubernetes deployments use.

ECR repository infra code is extremely simple. I created an ecr-repositories module to abstract the ecr stuff so that I can import only one module in the main env-def environment definition. I create the three ecr repositories in that ecr-repositories module using the same ecr Terraform module.


### Using Terraform to Create the AWS EKS Infrastructure

You need an AWS account and access key and secret key stored in your .aws directory, of course. From now on we assume that you have configured an AWS profile and we refer to that AWS profile as YOUR-AWS-PROFILE.

You need to manually create the S3 bucket for the terraform state and you also need manually to create a DynamoDB lock table (so that only one developer can run cloud infra changes at a time). I could have provided aws cli command script for these entities but they are also easy to create using the AWS Portal (and this is a one time task so no special need to automate this step).

Go to terraform/envs/dev directory. Give commands:

```bash
AWS_PROFILE=YOUR-AWS-PROFILE terraform init    # => Initializes Terraform, gets modules...
AWS_PROFILE=YOUR-AWS-PROFILE terraform plan    # => Shows the plan (what is going to be created...)
AWS_PROFILE=YOUR-AWS-PROFILE terraform apply   # => Apply changes
```


### Connecting to AWS EKS.

First you have to install [aws-cli](https://github.com/aws/aws-cli) and [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html).

Then you have to install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) tool.

Then we configure kubectl context for our new AWS EKS Kubernetes cluster:

```bash
# First use terraform to print the cluster name:
AWS_PROFILE=YOUR-AWS-PROFILE terraform output -module=env-def.eks
# Then get the Kubernetes cluster context:
AWS_PROFILE=YOUR-AWS-PROFILE aws eks update-kubeconfig --name YOUR-EKS-CLUSTER-NAME
# Check the contexts:
AWS_PROFILE=YOUR-AWS-PROFILE kubectl config get-contexts  # => You should find your new EKS context there.
# Check initial setup of the cluster:
AWS_PROFILE=YOUR-AWS-PROFILE kubectl get all --all-namespaces  # => prints the system pods...
```

If you finally see stuff belonging to kube-system namespace you should be good to go.

Then you have to join the worker nodes to the EKS cluster (following instructions in [Terraform EKS Introduction](https://learn.hashicorp.com/terraform/aws/eks-intro)):

```bash
# Store the config map that is needed in the next command.
# NOTE: Store file outside your git repository.
AWS_PROFILE=YOUR-AWS-PROFILE terraform output -module=env-def.eks-worker-nodes > ../../../tmp/config_map_aws_auth.yml
emacs ../../../tmp/config_map_aws_auth.yml  # => Delete the first rows until "apiVersion: v1"
AWS_PROFILE=YOUR-AWS-PROFILE kubectl apply -f ../../../tmp/config_map_aws_auth.yml
# In terminal 2:
while true; do echo "*****************" ; AWS_PROFILE=YOUR-AWS-PROFILE kubectl get all --all-namespaces   ; sleep 10; done
```

You should see the worker nodes getting created and starting to run. In my first try the worker nodes crashed.


### Debugging Why the First Attempt to Create EKS Failed

When checking the pods with describe and logs there was some info: Describe: "Back-off restarting failed container", Logs: "=====Starting amazon-k8s-agent =========== ERROR: logging before flag.Parse: W0116 18:25:39.734868      10 client_config.go:533] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work."  Merry Christmas - nice to start googling the reason for this. First I created a key pair and configured the worker node configuration to use that key pair so that I would be able to ssh to worker node instances to see what's happening there. Ssh'ed to EC2 and then checked what's happening in the docker land: docker ps -a | wc -l => 41, Merry Christmas. 41, wtf? I checked that the current EKS version is 1.11. So, instead of getting the newest AMI with a filter like in the original example, I chose the newest AMI which had "1.11" in its name.

I must say that the basic Kubernetes as a Service configuration in the Azure side (AKS) was a lot simpler. The worker node configuration and hassle makes the Kubernetes as a Service configuration a lot more complex in the AWS side.

Now logs says: "ERROR: logging before flag.Parse: W0116 19:45:52.005365      13 client_config.go:533] Neither --kubeconfig nor --master was specified.  Using the inClusterConfig.  This might not work. Failed to communicate with K8S Server. Please check instance security groups or http proxy setting"

Ok. Let's continue this tomorrow and figure out why there is this **Failed to communicate with K8S Server. Please check instance security groups or http proxy setting** error.

After some debugging I think I found the error. The Terraform EKS Introduction says: "NOTE: The usage of the specific kubernetes.io/cluster/* resource tags below are required for EKS and Kubernetes to discover and manage networking resources." I forgot to add this tag to certain resources. Let's destroy everything, add the required tags, review all code and then create everything again.

I fixed the tag issue but still same problems. Then I decided to follow one cloud infra best practice: create a reference implementation that should work so that you can compare your solution with the reference solution resource by resource. I git cloned the Terraform example [eks-getting-started](https://github.com/terraform-providers/terraform-provider-aws/tree/master/examples/eks-getting-started), changed region and vpc address space (the one in the original example was already taken) and deployed infra to my AWS account. This version deployed ok and EKS cluster was healthy. So, I had a healthy reference baseline to compare my not-working EKS resource by resource. Pretty soon I realized that I have to make one change: the EKS cluster name needs to be set before anything else and then the cluster name needs to be injected into vpc, eks and eks-worker-nodes modules. And there was also a bug in one security group id reference which I also fixed. Now my own EKS cluster setup also worked as the reference setup.

Actually, it was a kind of good thing that I didn't get the setup right the first time. Now I had to spend some serious cloud infra debugging time to figure out how the setup actually is supposed to work and not just blindly follow some black box example.


### Observations

**EKS worker node hassle.** The EKS cluster itself is easy to create, but the worker node hassle was really painful in the AWS EKS compared to Azure AKS (in which you didn't have to create any separate worker nodes).

**Creating EKS takes really long.** It took over 10 minutes to create EKS. And after EKS terraform tells AWS to create the launch configuration for worker nodes, then worker node instances are created according to launch configuration template... takes time.



### Links to External Documentation

- [Terraform AWS EKS Introduction](https://learn.hashicorp.com/terraform/aws/eks-intro)
- [What is Aamazon EKS?](https://docs.aws.amazon.com/eks/latest/userguide/what-is-eks.html)
