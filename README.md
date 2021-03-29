# GKE Preemptible Nodes Tutorial

## Table of Contents
- [Introduction](#introduction)
  * [Caveats](#caveats)
- [Prerequisites](#prerequisites)
  * [General understanding of Terraform and Kubernetes](#general-understanding-of-terraform-and-kubernetes)
  * [OS](#os)
  * [Google Project and IAM](#google-project-and-iam)
  * [Docker](#docker)
- [Setup environment](#setup-environment)
- [Terraform](#terraform)
  * [Configure](#configure)
  * [Create the cluster](#create-the-cluster)
  * [Scale down fallback node pool](#scale-down-fallback-node-pool)
- [Kubernetes](#kubernetes)
  * [Setup Kubernetes environment](#setup-kubernetes-environment)
  * [Apply podsecuritypolicy defaults manifests](#apply-podsecuritypolicy-defaults-manifests)
  * [Apply priorityclass manifests](#apply-priorityclass-manifests)
  * [Deploy node-termination-handler](#deploy-node-termination-handler)
  * [Deploy nginx](#deploy-nginx)
- [Cleanup](#cleanup)

## Introduction
This tutorial is meant to be a nitty gritty technical how-to that pairs with this blog post: [Migrating to Kubernetes and GKE: Preemptible nodes and making space for the Chaos Monkeys](https://expel.io/blog/migrating-gke-preemptible-nodes-making-space-for-chaos-monkeys?utm_medium=referral&utm_source=author%20promo&utm_campaign=Social%20blog%20promo). Reading the article first will give a lot more context to why many of the things in this repo are done.

In this tutorial, we will setup a GKE cluster following many "best practices" using Terraform. These best practices include:
- Automatic updates following the `STABLE` [release channel](https://cloud.google.com/kubernetes-engine/docs/concepts/release-channels)
- Setting maintenance window outside of standard work hours (in our case, SAT, SUN EST 8 PM - 8 AM)
- Enabling [shielded nodes](https://cloud.google.com/kubernetes-engine/docs/how-to/shielded-gke-nodes)
- Enabling [PodSecurityPolicies](https://cloud.google.com/kubernetes-engine/docs/how-to/pod-security-policies)
- Enabling [Vertical Pod autoscaling](https://cloud.google.com/kubernetes-engine/docs/concepts/verticalpodautoscaler)
- Enabling [cluster autoscaling for node pools](https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler)
- Using [VPC Native networking](https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips)
- Minimizing privileges of [GKE's GCP service account](https://cloud.google.com/kubernetes-engine/docs/how-to/hardening-your-cluster#use_least_privilege_sa)
- Using [GKE regional cluster](https://cloud.google.com/kubernetes-engine/docs/concepts/regional-clusters)

Along with these general best practices, this cluster will have a node pool of preemptible instances which appropriate workloads can take advantage of to save money.

We will also be deploying node-termination-handler and an example workload (nginx in this case). These will be deployed with the following Kubernetes features:
- Pod disruption budgets (PDB):
- Priority classes:
- Pod security policies (PSP):
- Vertical pod autoscaling (VPA):

### Caveats

Running a web server or publicly accessible API on preemptible nodes is not necessarily recommended. The nginx workload was chosen as it as a very common workload the user might have familiarity with. How nginx is deployed in this repo could still result in brief downtime (in the range of seconds) in rare edge cases.

## Prerequisites

### General understanding of Terraform and Kubernetes
It is assumed that those following this tutorial are reasonably comfortable with Docker, Terraform, and Kubernetes/GKE.

### OS
This tutorial has been tested with Docker on OS X and Linux. This has not been tested with Docker for Windows. However, it may work with very small modifications.

### Google Project and IAM
It is safest and suggested that this tutorial be deployed in a fresh test project. This will prevent possible collision of preexisting resource names. It also assumes your Google Account has appropriate IAM permissions in this project. This repo was tested with an account that had `owner` on the project.

### Docker
Docker is needed to build and run the image defined in the Dockerfile found in the root of the repo.

## Setup environment

**NOTE:** shell commands that start with `root@DOCKER:/PATH#` are meant to be run inside of the docker container. Also note the path as this is where the command is meant to be run

```
# Build the container
$ docker build -t tutorial .

# Run the container
$ docker run -it --name tutorial --volume $PWD:/tutorial tutorial

# Initialize and authenticate the google-sdk inside of the container
# Follow the prompts making sure to select your test project
root@DOCKER:/tutorial# gcloud init

# Setup default service account authentication for terraform to use
# You may recieve a warning about "Google Cloud SDK without a quota project" which is safe to ignore
root@DOCKER:/tutorial# gcloud auth application-default login

# Now enable required APIs in the project:
root@DOCKER:/tutorial# gcloud services enable compute.googleapis.com
root@DOCKER:/tutorial# gcloud services enable container.googleapis.com
```

If you exit the container/shell the container will stop. To re-enter it run:

```
$ docker start -i -a tutorial
```

## Terraform

### Configure

A common pattern at Expel is to drive Terraform configuration with a json file. We find that this allows us to abstract specific configuration for a workspace / environment out in a centralized way. This top level json file allows the objects to be consumed by things other than Terraform such as jsonnet (or anything else that supports ingesting json). The variables defined in the json must still be defined in the Terraform. These definitions can be found in `tf/variables.tf`

Enter the `/tf` dir and create `inputs.auto.tfvars.json` from template file:

```
root@DOCKER:/tutorial# cd tf
root@DOCKER:/tutorial/tf# cp inputs.template.json inputs.auto.tfvars.json
```

The reason for this weird naming is that any file ending with `.auto.tfvars` or `.auto.tfvars.json` will automatically be loaded by Terraform as variables.

Now modify `inputs.auto.tfvars.json`, making sure to at minimum replace the following fields that have their values set to REPLACE (vim and nano are available in the container):

```
{
  ...
  // The name of the cluster, suggestion: preempt-tutorial
  "cluster": "REPLACE",
  // GCP project to create resources in
  "project": "REPLACE",
  // GCP region to create resources in, such as `us-east1`
  "region": "REPLACE",
  ...
}
```

### Create the cluster

First initialize Terraform:

```
root@DOCKER:/tutorial/tf# terraform init
Initializing modules...
- nodepool in modules/nodepool

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/google-beta from the dependency lock file
- Reusing previous version of hashicorp/google from the dependency lock file
- Installing hashicorp/google-beta v3.51.1...
- Installed hashicorp/google-beta v3.51.1 (signed by HashiCorp)
- Installing hashicorp/google v3.56.0...
- Installed hashicorp/google v3.56.0 (signed by HashiCorp)

Terraform has been successfully initialized!

You may now begin working with Terraform. Try running "terraform plan" to see
any changes that are required for your infrastructure. All Terraform commands
should now work.

If you ever set or change modules or backend configuration for Terraform,
rerun this command to reinitialize your working directory. If you forget, other
commands will detect it and remind you to do so if necessary.
```

Now apply the state defined in the Terraform files:

```
root@DOCKER:/tutorial/tf# terraform apply

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions (plan has been truncated in example):

  # google_container_cluster.cluster will be created
  + resource "google_container_cluster" "cluster" {
      + cluster_ipv4_cidr           = (known after apply)
      + datapath_provider           = (known after apply)
      + default_max_pods_per_node   = (known after apply)
...
      + upgrade_settings {
          + max_surge       = 1
          + max_unavailable = 0
        }
    }

Plan: 9 to add, 0 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Inspect the planned state diff and enter `yes` to proceed with the plan when prompted:

```
  Enter a value: yes
```

Terraform will now create the cluster, node pools, and other needed resources. This will take a while, around 10-15 minutes in testing.

**NOTE:** If the apply fails, attempt to apply again. There are rare race conditions that sometimes causes cluster and node pool creations to fail. Occasionally the Google API is taking longer than usual and there is a timeout.

You can inspect your new cluster and node pools in the Google console: https://console.cloud.google.com/kubernetes. Make sure to select the correct project in the top left of the header to the right of `Google Cloud Platform`.

Note if the cluster is in a "Repairing" state. This often happens on cluster creation. Google will run a `UPDATE_CLUSTER` operation followed by a `REPAIR_CLUSTER` operation that takes roughly 10-20 minutes. You can inspect this with the following command:

```
root@DOCKER:/tutorial/tf# gcloud container operations list
operation-1613526916137-2461d0c5  CREATE_CLUSTER      us-east1  preempt-tutorial                      DONE    2021-02-17T01:55:16.137525694Z  2021-02-17T01:58:16.858776151Z
operation-1613527103376-6366acf2  CREATE_NODE_POOL    us-east1  primary                               DONE    2021-02-17T01:58:23.376131942Z  2021-02-17T01:59:30.190644279Z
operation-1613527177481-30c7530a  CREATE_NODE_POOL    us-east1  preemptible-fallback                  DONE    2021-02-17T01:59:37.481627254Z  2021-02-17T02:00:38.132142128Z
operation-1613527241449-2e7c647c  CREATE_NODE_POOL    us-east1  preemptible                           DONE    2021-02-17T02:00:41.449840658Z  2021-02-17T02:01:42.221138005Z
operation-1613527396113-9e1de6ce  UPDATE_CLUSTER      us-east1  preempt-tutorial                      DONE    2021-02-17T02:03:16.113091172Z  2021-02-17T02:03:17.181680406Z
operation-1613527396364-f3510ff2  REPAIR_CLUSTER      us-east1  preempt-tutorial                      RUNNING 2021-02-17T02:03:16.364894425Z
```

You will need to wait for this to complete before continuing on.

### Scale down fallback node pool

When creating a node pool, it needs to have at least one node in it or the autoscaler will never kick in. See: https://cloud.google.com/kubernetes-engine/docs/concepts/cluster-autoscaler#limitations

Eventually the autoscaler will scale down the preemptible-fallback node pool, however it may not kick in before we start deploying our preemptible workloads. To be sure the deployments get deployed to the preemptible nodes, scale down the fallback node pool. Make sure to replace REGION and CLUSTER with the setting used in `inputs.auto.tfvars.json`:

```
root@DOCKER:/tutorial/k8s# gcloud container clusters resize --node-pool preemptible-fallback --num-nodes 0 --region REGION CLUSTER
Pool [preemptible-fallback] for [CLUSTER] will be resized to
0.

Do you want to continue (Y/n)?  y

Resizing CLUSTER...done.
Updated [https://container.googleapis.com/v1/projects/PROJECT/zones/REGION/clusters/CLUSTER].
```

## Kubernetes

### Setup Kubernetes environment

Navigate to the `k8s/` folder at the root of the repository:

```
root@DOCKER:/tutorial/tf# cd ../k8s/
```

Configure kubectl with the correct context for new cluster. Make sure to replace REGION and CLUSTER with the setting used in `inputs.auto.tfvars.json`:

```
root@DOCKER:/tutorial/k8s# gcloud container clusters get-credentials --region REGION CLUSTER
Fetching cluster endpoint and auth data.
kubeconfig entry generated for preempt-tutorial.
```

### Apply podsecuritypolicy defaults manifests

```
root@DOCKER:/tutorial/k8s# kubectl apply -f podsecuritypolicy-default/
clusterrole.rbac.authorization.k8s.io/psp:default created
clusterrolebinding.rbac.authorization.k8s.io/psp:default created
podsecuritypolicy.policy/default created
```

This will create a podsecuritypolicy (PSP) called default. This PSP is a minimum set of privileges that all pods will be allowed to use by default. Our nginx container will use this PSP.

### Apply priorityclass manifests

```
root@DOCKER:/tutorial/k8s# kubectl apply -f priorityclass/
priorityclass.scheduling.k8s.io/ops-critical created
priorityclass.scheduling.k8s.io/stateful-high created
priorityclass.scheduling.k8s.io/stateful-medium created
priorityclass.scheduling.k8s.io/stateful-low created
priorityclass.scheduling.k8s.io/stateless-high created
priorityclass.scheduling.k8s.io/stateless-medium created
priorityclass.scheduling.k8s.io/stateless-low created
```

This is a standard set of priorityclasses that we use for all of our clusters. Their priority is as listed above with highest first. In this tutorial, we will only be utilizing `ops-critical` and `stateless-high`.

### Deploy node-termination-handler

```
root@DOCKER:/tutorial/k8s# kubectl apply -f node-termination-handler/
clusterrole.rbac.authorization.k8s.io/node-termination-handler created
clusterrolebinding.rbac.authorization.k8s.io/node-termination-handler created
daemonset.apps/node-termination-handler created
podsecuritypolicy.policy/node-termination-handler created
serviceaccount/node-termination-handler created
verticalpodautoscaler.autoscaling.k8s.io/node-termination-handler created
```

You can inspect the running pods with the following command:

```
root@DOCKER:/tutorial/k8s# kubectl get pod -n kube-system -l app=node-termination-handler -o wide
NAME                             READY   STATUS    RESTARTS   AGE    IP            NODE                                             NOMINATED NODE   READINESS GATES
node-termination-handler-tkwnn   1/1     Running   0          2m8s   10.142.0.29   gke-preempt-tutorial-preemptible-ca3f473a-ksbs   <none>           <none>
```

If there are no pods, this is because the preemptible node pool has been scaled down, and node-termination-handler only runs on preemptible nodes. You can verify this like so:

```
root@DOCKER:/tutorial/k8s# kubectl get nodes -l workload-type=preemptible
No resources found
```

After deploying nginx, the preemptible node pool will be scaled up and the `kubectl get pod -l app=node-termination-handler -o wide` will show running pods.

### Deploy nginx

```
root@DOCKER:/tutorial/k8s# kubectl apply -f nginx/
configmap/nginx-confd created
deployment.apps/nginx created
ingress.networking.k8s.io/nginx created
poddisruptionbudget.policy/nginx created
service/nginx created
verticalpodautoscaler.autoscaling.k8s.io/nginx created
```

Verify the pods have successfully started:

```
root@DOCKER:/tutorial/k8s# kubectl get pod -n default -l app=nginx -o wide
NAME                     READY   STATUS    RESTARTS   AGE    IP             NODE                                             NOMINATED NODE   READINESS GATES
nginx-854499dc5d-5vcgn   1/1     Running   0          4m3s   10.120.0.195   gke-preempt-tutorial-preemptible-ca3f473a-ksbs   <none>           1/1
nginx-854499dc5d-rbggz   1/1     Running   0          4m3s   10.120.0.194   gke-preempt-tutorial-preemptible-ca3f473a-ksbs   <none>           1/1
nginx-854499dc5d-t2j2p   1/1     Running   0          4m2s   10.120.0.196   gke-preempt-tutorial-preemptible-ca3f473a-ksbs   <none>           1/1
```

If there are no pods, the preemptible node pool is being scaled up. You can verify this by describing the current replicaset for the nginx deployment:

```
root@DOCKER:/tutorial/k8s# kubectl get rs -n default -l app=nginx
NAME               DESIRED   CURRENT   READY   AGE
nginx-854499dc5d   3         3         3       9m45s
root@DOCKER:/tutorial/k8s# kubectl describe rs -n default nginx-854499dc5d
Name:           nginx-854499dc5d
Namespace:      default
Selector:       app=nginx,pod-template-hash=854499dc5d
...
Events:
  Type     Reason                   Age                From                     Message
  ----     ------                   ----               ----                     -------
  Warning  FailedScheduling         29s (x2 over 29s)  default-scheduler        0/3 nodes are available: 3 node(s) didn't match node selector.
  Normal   LoadBalancerNegNotReady  29s                neg-readiness-reflector  Waiting for pod to become healthy in at least one of the NEG(s): [k8s1-bf18422d-default-nginx-8080-22347d7e]
  Normal   TriggeredScaleUp         24s                cluster-autoscaler       pod triggered scale-up: [{https://content.googleapis.com/compute/v1/projects/PROJECT/zones/us-east1-d/instanceGroups/gke-preempt-tutorial-preemptible-ca3f473a-grp 0->1 (max: 10)}]
```

Once the node pool has scaled up (about 1 minute), the `kubectl get pod` command should show 3 healthy `Running` pods.

This also deployed an ingress which will cause GKE to create a HTTP load balancer to route external traffic to our nginx pods. Find the IP and test it:

```
root@DOCKER:/tutorial/k8s# kubectl get ingress -n default -l app=nginx
NAME    HOSTS   ADDRESS        PORTS   AGE
nginx   *       34.96.88.195   80      20m
root@DOCKER:/tutorial/k8s# curl http://34.96.88.195
So affordable, so available
```

And there it is! You have a working nginx deployment running on preemptible nodes!

## Cleanup

To cleanup all resources, run the following command inside the `/tf` folder:


```
root@DOCKER:/tutorial/tf# terraform destroy
```
