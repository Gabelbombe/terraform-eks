### Installation process for EKS

There are a few tools that allow you to get up and running quickly on EKS. Cloudformation, Terraform, and eksctl are all good options, with eksctl probably being the quickest way to get started. I will be using Terraform since we are planning on plugging it intop our pipeline already. Terraform provides a nice tutorial and sample code repository to help you create all the necessary AWS services to run EKS. Their sample code is a good starting place and you can easily modify it to better suit your AWS environment.

_NOTE:_ This tutorial will create a cluster in `us-west-2` using the `10.0.0.0/16` subnet.

What You'll Need

Before you get started, you'll need a few tools installed. Terraform is a tool to create, change, and improve infrastructure. Helm is a package management tool for Kubernetes. You'll need to install them both:

  - [terraform](https://www.terraform.io/downloads.html)
  - [helm](https://matthewpalmer.net/kubernetes-app-developer/articles/how-to-install-helm-mac.html)
  - [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html)
  - [aws-vault](https://github.com/99designs/aws-vault)


### Terraform

Let's start by cloning Terraform's EKS git repository from their AWS EKS Introduction. You'll need to have installed the git client, a version control tool, for your operating system for the next command. On Ubuntu systems, you can accomplish this with apt-get install git, and RedHat based systems with yum install git. Now you can clone the Terraform AWS repository:

```bash
$ git clone https://github.com/terraform-providers/terraform-provider-aws.git
```

Terraform tracks the state in which it makes changes to your infrastructure in a state file. You'll want to go into the examples directory, and initialize Terraform with init. This will initialize Terraform, creating the state file to track our work:

```bash
$ cd terraform-provider-aws/examples/eks-getting-started && terraform init
```

Now, to see a detailed outline of the changes Terraform would make, run plan. This should include the EKS cluster, VPC, and other AWS resources that will be facilitated in this project:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m -- terraform plan
```

Make sure to review the changes. The plan command will additionally warn you if there are any errors in your Terraform code. Assuming everything looks alright, since this is a fresh checkout, you should be able to apply the default configuration using the apply:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m -- terraform apply
```

Terraform will prompt you to make sure that you want to apply the changes, since this will create resources that will incur charges on our AWS account. You'll want to go ahead and apply the changes since you already reviewed them with the plan command previously:

```bash
Do you want to perform these actions?
Terraform will perform the actions described above.
Only 'yes' will be accepted to approve.

Enter a value: yes
```

By default, the resources are targeted to be created in us-west-2, so bear that in mind if you go looking for the resources created in your console. This apply step will create many of the resources you need to get up and running initially, including:

- VPC
- IAM roles
- Security groups
- An internet gateway
- Subnets
- Autoscaling group
- Route table
- EKS cluster
- Your kubectl configuration

### Setting Up kubectl

You will need the configuration output from Terraform in order to use kubectl to interact with your new cluster. Create your kube configuration directory, and output the configuration from Terraform into the config file using the Terraform output command:

```bash
mkdir ~/.kube/
terraform output kubeconfig>~/.kube/config
```

You'll need kubectl, a command line tool to run commands against Kubernetes clusters, for the next step. Installation instructions can be found here. Once you've got this installed, you'll want to check to make sure that you're connected to your cluster by running kubectl version. Your output may vary slightly here:

```bash
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"12", GitVersion:"v1.12.1", GitCommit:"4ed3216f3ec431b140b1d899130a69fc671678f4", GitTreeState:"clean", BuildDate:"2018-10-05T16:46:06Z", GoVersion:"go1.10.4", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"12+", GitVersion:"v1.12.6-eks-d69f1b", GitCommit:"d69f1bf3669bf00b7f4a758e978e0e7a1e3a68f7", GitTreeState:"clean", BuildDate:"2019-02-28T20:26:10Z", GoVersion:"go1.10.8", Compiler:"gc", Platform:"linux/amd64"}
```

Now let's add the ConfigMap to the cluster from Terraform as well. The ConfigMap is a Kubernetes configuration, in this case for granting access to our EKS cluster. This ConfigMap allows our ec2 instances in the cluster to communicate with the EKS master, as well as allowing our user account access to run commands against the cluster. You'll run the Terraform output command to a file, and the kubectl apply command to apply that file:

```bash
terraform output config_map_aws_auth > configmap.yml
aws-vault exec GEHC-077 --assume-role-ttl=60m -- kubectl apply -f configmap.yml
```

Once this is complete, you should see your nodes from your autoscaling group either starting to join or joined to the cluster. Once the second column reads Ready the node can have deployments pushed to it. Again, your output may vary here:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m -- kubectl get nodes -o wide
NAME                                       STATUS   ROLES    AGE   VERSION              INTERNAL-IP   EXTERNAL-IP      OS-IMAGE         KERNEL-VERSION                  CONTAINER-RUNTIME
ip-10-0-0-148.us-west-2.compute.internal   Ready    <none>   44s   v1.13.7-eks-c57ff8   10.0.0.148    54.202.123.231   Amazon Linux 2   4.14.128-112.105.amzn2.x86_64   docker://18.6.1
ip-10-0-1-84.us-west-2.compute.internal    Ready    <none>   44s   v1.13.7-eks-c57ff8   10.0.1.84     18.237.80.220    Amazon Linux 2   4.14.128-112.105.amzn2.x86_64   docker://18.6.1
```

At this point, your EKS cluster is up, the nodes have joined, and they are ready for a deployment!

### Helm

Next, you'll install Helm. First you need to create a Kubernetes ServiceAccount for tiller, which allows helm to talk to the cluster:

```yaml
cat >tiller-user.yaml <<EOF
  apiVersion: v1
  kind: ServiceAccount
  metadata:
    name: tiller
    namespace: kube-system
  ---
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: tiller
  roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: ClusterRole
    name: cluster-admin
  subjects:
    - kind: ServiceAccount
      name: tiller
      namespace: kube-system
EOF
```

Now, you apply the ServiceAccount with kubectl, and install helm with the init command:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m -- kubectl apply -f tiller-user.yaml
$ aws-vault exec GEHC-077 --assume-role-ttl=60m -- helm init --service-account tiller
```

Your output should look similar to this:

```bash
NAME:   my-nginx
LAST DEPLOYED: Thu Aug  8 14:04:39 2019
NAMESPACE: default
STATUS: DEPLOYED

RESOURCES:
==> v1/Pod(related)
NAME                                                     READY  STATUS             RESTARTS  AGE
my-nginx-nginx-ingress-controller-65d5b555d9-47wxn       0/1    ContainerCreating  0         0s
my-nginx-nginx-ingress-default-backend-5b69b8cf6c-t4w8t  0/1    ContainerCreating  0         0s

==> v1/Service
NAME                                    TYPE          CLUSTER-IP      EXTERNAL-IP  PORT(S)                     AGE
my-nginx-nginx-ingress-controller       LoadBalancer  172.20.211.121  <pending>    80:31861/TCP,443:30423/TCP  0s
my-nginx-nginx-ingress-default-backend  ClusterIP     172.20.27.101   <none>       80/TCP                      0s

==> v1/ServiceAccount
NAME                    SECRETS  AGE
my-nginx-nginx-ingress  1        1s

==> v1beta1/ClusterRole
NAME                    AGE
my-nginx-nginx-ingress  1s

==> v1beta1/ClusterRoleBinding
NAME                    AGE
my-nginx-nginx-ingress  0s

==> v1beta1/Deployment
NAME                                    READY  UP-TO-DATE  AVAILABLE  AGE
my-nginx-nginx-ingress-controller       0/1    1           0          0s
my-nginx-nginx-ingress-default-backend  0/1    1           0          0s

==> v1beta1/Role
NAME                    AGE
my-nginx-nginx-ingress  0s

==> v1beta1/RoleBinding
NAME                    AGE
my-nginx-nginx-ingress  0s
```

> NOTES:
> The nginx-ingress controller has been installed.
> It may take a few minutes for the LoadBalancer IP to be available.
> You can watch the status by running `kubectl --namespace default get services -o wide -w my-nginx-nginx-ingress-controller`

An example Ingress that makes use of the controller:

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: example
  namespace: foo
spec:
  rules:
    - host: www.example.com
      http:
        paths:
          - backend:
              serviceName: exampleService
              servicePort: 80
            path: /
  # This section is only required if TLS is to be enabled for the Ingress
  tls:
    - hosts:
        - www.example.com
      secretName: example-tls
```

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: example-tls
  namespace: foo
data:
  tls.crt: <base64 encoded cert>
  tls.key: <base64 encoded key>
type: kubernetes.io/tls
```

You will need a way for our Airflow deployment to communicate with the outside world. For this, you will install nginx-ingress, an ingress controller that uses ConfigMap to store nginx configurations. Nginx is an industry standard software for web and proxy servers. We will use the proxy feature to serve up our Airflow web interface. Install nginx-ingress via the helm chart:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m --  \
helm install stable/nginx-ingress                   \
  --name my-nginx                                   \
  --set rbac.create=true
```

### Airflow

You need to override some values in the Airflow chart to tell it to use the nginx ingress controller. You'll want to replace `airflow-k8s.gehc.com` with a hostname of your own:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tiller
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: tiller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: tiller
  namespace: kube-system
```

Finally, you install Airflow via the helm chart and the values file you just created using the helm install command:

```bash
$ aws-vault exec GEHC-077 --assume-role-ttl=60m --  \
helm install stable/airflow                       \
  --namespace "airflow"                           \
  --name airflow                                  \
-f values.yaml
```

This may take a few moments before all of the pods are ready, and you can monitor the progress with:

```bash
$ watch "kubectl get pods -n airflow"
```

Even after the pods are running, I've found it takes at least five minutes for everything to completely spin up.

You can find out the internet accessible endpoint by querying the services and looking for the LoadBalancer Ingress

```bash
$ kubectl describe services |grep ^LoadBalancer LoadBalancer Ingress: 8a69022e5f102be1072e5fb1087f5fbe-e907efv7e8.us-west-2.elb.amazonaws.com
```

If you visit this URL, you will find the flower interface, a web tool for monitoring and administering celery clusters.

To reach the Airflow administrative interface, you will need to add an entry to /etc/hosts, but first you need to get the IP address of that LoadBalancer Ingress, and add it to your /etc/hosts:

```yaml
cat >values.yaml <<EOF
ingress:
  enabled: true
  web:
    path: "/"
    host: "airflow-k8s.gehc.com"
    tls:
      enabled: true
    annotations:
      kubernetes.io/ingress.class: "nginx"
EOF
```

Afterwards, you can reach the Airflow administrative interface from the URL http://airflow-k8s.gehc.com in your browser. Under a production environment, you would replace airflow-k8s.gehc.com with a FQDN that you can add as an alias in route53 to point to the ELB created by the LoadBalancer Ingress.

### Cleaning Up

To destroy these resources, delete the helm deployments, and issue a destroy with Terraform

```bash
$ helm del --purge airflow;
$ helm del --purge my-nginx;
$ terraform destroy
```
