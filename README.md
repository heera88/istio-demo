
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

Run `make expose-myappv1` (included in makefile). This is what v1 of the demo app should look like:

![v1 of myapp](./static/vblue.png)

Now, run `make expose-myappv2`. And, this is how v2 of the demo app should look like:
![v2 of myapp](./static/vgreen.png)

## Let's bring in Istio

Istio can automatically inject the sidecar envoy proxy in your application pods but for the demo, I manually injected the proxy to show the difference.

Run `kubectl apply -f <(istioctl kube-inject -f configs/myapp-deployment.yml)`

Now if you run `kubectl get pods -lapp=myapp` again, you'll see something like:

```
NAME                        READY   STATUS    RESTARTS   AGE
myapp-v1-57c9b98d89-nvgdw   2/2     Running   0          108s
myapp-v2-5bb8df789d-2xkqq   2/2     Running   0          108s
```

The sidecar proxy has been injected and in each pod, you have 2 containers running. 

## Gateway, DestinationRule and VirtualService

By default, any service running inside the service mesh is not automatically exposed outside of the cluster which means that we can’t get to it from the public Internet.

To allow incoming traffic to the frontend service that runs inside the cluster, we need to create an external load balancer first. As part of the installation, Istio creates an  `istio-ingressgateway`  service that is of type  `LoadBalancer`and, with the corresponding Istio  `Gateway`  resource, can be used to allow traffic to the cluster.

If you run `kubectl get svc istio-ingressgateway -n istio-system`, you will get an output similar to this one:

```
NAME TYPE CLUSTER-IP  EXTERNAL-IP PORT(S)  AGE

istio-ingressgateway LoadBalancer 10.105.99.205 10.105.99.205 15020:30483/TCP,80:31380/TCP,443:31390/TCP,31400:31400/TCP,15029:32056/TCP,15030:30526/TCP,15031:30331/TCP,15032:31149/TCP,15443:31129/TCP 53d
```
The above output shows the Istio ingress gateway of type `LoadBalancer`.

You can now create a `Gateway` that points to this ingressgateway to allow traffic into your cluster. To do this, run `kubectl apply -f configs/gateway.yml`

DestinationRule is a way to group your service into subsets. 

```
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: myapp
spec:
  host: myapp
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
```

In the above DestinationRule, I am dividing the `myapp` service into 2 subsets based on versions, v1 & v2, using k8s labels.

VirtualService is the set of rules you define to control the traffic flow. Let's take a look at this simple VirtualService first:

```
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: myapp
spec:
  hosts:
  - "*"
  gateways:
  - app-gateway
  http:
    - route:
      - destination:
          host: myapp
          subset: v1
        weight: 50
      - destination:
          host: myapp
          subset: v2
        weight: 50  
```

Using the above VirtualService, I'm telling Istio to send 50% traffic to v1 of my demo app and 50% traffic to v2. 

To apply this rule, run `kubectl apply -f configs/even-split-traffic.yml`

In another terminal window, you can run `make call-svc` command and you'll see the traffic being sent evenly to both versions of the demo app. This should look similar to k8s' round-robin way.

```
$ make call-svc

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>
<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>
<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>
<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>
<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>
<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>
```   

### Let's make it more fun!!!

I want to start sending more traffic to v1 of the demo app. Run `kubectl apply -f configs/percentage-split-traffic.yml`

If you run, `make call-svc` command again, you'll now see more requests being sent to v1 (80%) of the demo app.  
```
  http:
    - route:
      - destination:
          host: myapp
          subset: v1
        weight: 80
      - destination:
          host: myapp
          subset: v2
        weight: 20  
```
## A/B Testing

Now, if you were doing A/B testing and wanted to start sending a small subset of users to a different version of the application, you can do so with Istio. 

Run `kubectl apply -f configs/header-split-traffic.yml` and `make call-svc` again. 

You will see all requests being sent to v2 of the app. 

```
$ make call-svc

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>
```

Now run `make call-svc-custom-header` and you'll see all requests being sent to v1 of the app. 

```
$ make call-svc-custom-header

while : ;do export GREP_COLOR='1;33';curl -s -H "foo:bar" http://192.168.99.100:31380/  |  grep --color=always "V1" ; export GREP_COLOR='1;36'; curl -s  -H "foo:bar" http://192.168.99.100:31380/  | grep --color=always "V2" ; sleep 1; done

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1> 

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V1 of the app</h1>
```

#### Why ?? 
Because if you look closely at the curl command for `call-svc-custom-header`, you'll see the custom header "foo:bar" being passed in the request, as specified in the VirtualService.

```
  http:
  - match:
    - headers:
        foo:
          exact: bar
    route:
      - destination:
          host: myapp
          subset: v1
  - route:
    - destination:
        host: myapp
        subset: v2
```

## Give your microservice(s) a break
In the real world, services fail all the time! Unit/Integration tests don't account for failures in network stability. One of the challenges is to be able to simulate errors. Let's see how Istio makes this so easy!

Run `kubectl apply -f configs/fault-injection.yml`

Now run `make call-svc`. All the requests should go to v2 of the app. 

```
$ make call-svc

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>

<h1 style="color:white;text-align:center">Welcome to V2 of the app</h1>
```

And now run `make print-http-response`. All requests should come back with a HTTP 200 OK response.

```
$ make print-http-response

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 200 OK
``` 

But if you run `make print-http-response-chaos`, you'll see ~30% of your requests failing.

```
$ make print-http-response-chaos

while true;sleep 1s;do curl -si -H "end-user:jason" http://192.168.99.100:31380/ | fgrep 'HTTP/1.1';done

HTTP/1.1 400 Bad Request

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 400 Bad Request

HTTP/1.1 200 OK

HTTP/1.1 400 Bad Request

HTTP/1.1 200 OK

HTTP/1.1 200 OK

HTTP/1.1 400 Bad Request

HTTP/1.1 200 OK

HTTP/1.1 400 Bad Request

HTTP/1.1 200 OK

HTTP/1.1 200 OK
``` 

#### Why ?
Because in configs/fault-inject.yml, I have a rule that says if a custom header "end-user: jason" is present in the request, the requests should go to v1 of myapp and 30% of the requests should fail with HTTP 400. 

#### Load Testing

Fortio is a load testing tool, I used to generate the success/failure report.

Run `kubectl apply -f configs/fortio.yml`

Run `make fault-report`. It will send requests to our demo service and print out a report at the end. At the bottom of the report, you'll see something like:

```
Code 200 : 71 (71.0 %)

Code 400 : 29 (29.0 %)

Response Header Sizes : count 100 avg 174.75 +/- 111.7 min 0 max 247 sum 17475

Response Body/Total Sizes : count 100 avg 336.82 +/- 119.4 min 150 max 414 sum 33682

All done 100 calls (plus 0 warmup) 40.151 ms avg, 49.2 qps
``` 

## Retries

Network is unreliable!!! Some requests may fail due to these network blips but succeed next time you retry. Istio can help you retry such requests with zero changes to your code. 

Run `kubectl apply -f configs/retry.yml`