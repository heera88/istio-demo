FORTIO_POD=$(shell kubectl get pod -l app=fortio -o jsonpath="{.items[0].metadata.name}")
INGRESS_HOST=$(shell minikube ip)
INGRESS_PORT=$(shell kubectl -n istio-system get service istio-ingressgateway -o jsonpath='{.spec.ports[?(@.name=="http2")].nodePort}')

grafana:
	kubectl port-forward deployment/grafana 3000:3000 -n istio-system
load-report:
	kubectl exec -it $(FORTIO_POD) -c fortio /usr/bin/fortio -- load -c 2 -qps 0 -n 100 -loglevel Warning http://$(INGRESS_HOST):$(INGRESS_PORT)/
fault-report:
	kubectl exec -it $(FORTIO_POD) -c fortio /usr/bin/fortio -- load -c 2 -qps 0 -n 100 -H "end-user:jason" -loglevel Warning http://$(INGRESS_HOST):$(INGRESS_PORT)/
print-http-response-chaos:
	while true;sleep 1s;do curl -si -H "end-user:jason" http://$(INGRESS_HOST):$(INGRESS_PORT)/ | fgrep 'HTTP/1.1';done
print-http-response:
	       while true;sleep 1s;do curl -si http://$(INGRESS_HOST):$(INGRESS_PORT)/ | fgrep 'HTTP/1.1';done
call-svc:
	while : ;do export GREP_COLOR='1;33';curl -s  http://$(INGRESS_HOST):$(INGRESS_PORT)/  |  grep --color=always "V1" ; export GREP_COLOR='1;36'; curl -s  http://$(INGRESS_HOST):$(INGRESS_PORT)/  | grep --color=always "V2" ; sleep 1; done
call-svc-custom-header:
	while : ;do export GREP_COLOR='1;33';curl -s -H "foo:bar" http://$(INGRESS_HOST):$(INGRESS_PORT)/  |  grep --color=always "V1" ; export GREP_COLOR='1;36'; curl -s  -H "foo:bar" http://$(INGRESS_HOST):$(INGRESS_PORT)/  | grep --color=always "V2" ; sleep 1; done
expose-myappv1:
	kubectl port-forward deployment/myapp-v1 8080:80
expose-myappv2:
	kubectl port-forward deployment/myapp-v2 8080:80
teardown:
	kubectl delete pods,svc,deployments,virtualservice,destinationrule -lapp=myapp
