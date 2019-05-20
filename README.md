# Istio in Action

This is the code I used for my Istio talk - to demonstrate Istio's traffic management capabilities. 

## Cluster Setup

While Istio is platform independent, I used it with k8s to showcase its traffic shaping capabilities at the application layer.  

To follow along, you'll need a k8s cluster.

I used a local `minikube` single-node cluster for this demo, but the configs in this repo should still apply to your other k8s clusters.


## Istio Setup

Your needs and platform may differ. It's best to choose a flow that suits your needs.

[Istio Installation guide]
(https://istio.io/docs/setup/kubernetes/install/)


## Deploying the demo app

`kubectl apply -f configs/myapp-deployment.yml`

The above command will create a service called `myapp` and 2 pods 

```
$ kubectl get svc,pods -lapp=myapp

NAME            TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/myapp   ClusterIP   10.102.97.213   <none>        80/TCP    13h

NAME                            READY   STATUS    RESTARTS   AGE
pod/myapp-v1-56f56c765d-xd4x9   1/1     Running   0          13h
pod/myapp-v2-f7cbf8f6d-84d4p    1/1     Running   0          13h
```


## Let's talk about the demo app

To represent two different versions of the demo application, I have built simple Nginx based docker images – heera88/blue-green-app:v1 and heera88/blue-green-app:v2. When deployed, they show a static page with a blue or green background.

Let's see what `V1` and `V2` look like. 

Run `make expose-myappv1` (included in makefile). 

![v1 of myapp](./static/vblue.png)

Now, run `make expose-myappv2` 
![v2 of myapp](./static/vgreen.png)
