# RollingUpdate, Canary, Blue/Green Deployments on Kubernetes


git clone https://github.com/googlecodelabs/orchestrate-with-kubernetes.git
cd orchestrate-with-kubernetes/kubernetes

gcloud config set compute/zone us-central1-a
gcloud container clusters create bootcamp --num-nodes 5 --scopes "https://www.googleapis.com/auth/source.read_write,storage-rw"

kubectl explain deployment
kubectl explain deployment --recursive
kubectl explain deployment.metadata.name

sudo sed "s/auth:2.0.0/auth:1.0.0/g" deployments/auth.yaml

kubectl create -f deployments/auth.yaml
kubectl create -f services/auth.yaml

kubectl create -f deployments/hello.yaml
kubectl create -f services/hello.yaml

kubectl get deployments
kubectl get replicasets
kubectl get pods


# check out deployments/frontend.yaml file for configMap example
# spec:
#   containers:
#     volumeMounts:
#       - name: xxxx
#         mountPath: xxxxxx
#       -name: "tls-certs"
#    volumes:
#         - name: xxxxxxx
#           secret:
#             secretName: xxxx
#         - name: "nginx-frontend-conf"
#           configMap:
#             name: "nginx-frontend-conf"
#             items:
#               - key: "frontend.conf"
#                  path: "frontend.conf"

kubectl create secret generic tls-certs --from-file tls/
kubectl create configmap nginx-frontend-conf --from-file=nginx/frontend.conf
kubectl create -f deployments/frontend.yaml
kubectl create -f services/frontend.yaml

curl http://`kubectl get service frontend -o jsonpath="{.status.loadBalancer.ingress[0].ip}"`

kubectl explain deployment --recursive
kubectl explain deployment.metadata.name
kubectl explain deployment.spec.replicas

kubectl scale deployment hello --replicas=5
kubectl scale deployment hello --replicas=3

kubectl edit deployment hello
# change hello:1.0.0 back to hello:2.0.0
#  rollout update automatically start once the file deployment/hello.yaml is changed.

kubectl get replicasets

kubectl rollout status deployment xxxxx

kubectl rollout pause deployment xxxxx
kubectl rollout resume deployment xxxxx

kubectl rollout undo deployment xxxxx

kubectl rollout history deployment xxxxx
kubectl rollout history deployment/xxxxx
# example output:
# REVISION  CHANGE-CAUSE
# 1         kubectl apply --filename=apache_deployment.yaml --record=true
# 2         kubectl set image deployment apache-deployment frontend=nginx:1.7.9 --record=true


kubectl rollout undo deployment xxxxx
# will roll back to version 1. Check pod image to verify:
kubectl get pods -o jsonpath --template=`{range .item[*]}{.metadata.name}{"\t"}{"\t"}{.spec.containers[0].image}{"\n"}{end}`

kubectl describe deployments | grep Strategy

kubectl get replicasets


# RollingUpdate Deployment
#
# spec:
#   strategy:
#   type: RollingUpdate
#   rollingUpdate:
#     maxSurge: 1
#     maxUnavailable: 50%



kubectl scale deployment xxxxx --replicas=6
kubectl autoscale deployment xxxxx --min=6 --max=10 --cpu-percent=70





# Canary Deployment
#
# spec:
#   strategy:
#   type: Canary
#   canaryUpdate:
    
#  create canary deployment
kubectl create -f deployments/hello-canary.yaml
kubectl get deployments

# run curl several times and you can see version 1 and 2. 75%:25%
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version

# canary deployment in production should use sessionAffinity=clientIP in service yaml file
# kind: Service
# apiVersion: v1
# metadata:
#   name: "hello"
# spec:
#   sessionAffinity: ClientIP
#   selector:
#     app: "hello"
#   ports:
#     - protocol: "TCP"
#       port: 80
#       targetPort: 80



# blue/green deployment
kubectl apply -f services/hello-blue.yaml
# apiVersion: extensions/v1beta1
# kind: Deployment
# metadata:
#   name: hello-green
# spec:
#   replicas: 3
#   template:
#     metadata:
#       labels:
#         app: hello
#         track: stable
#         version: 2.0.0
#     spec:
#       containers:
#         - name: hello
#           image: kelseyhightower/hello:2.0.0
#           ports:
#             - name: http
#               containerPort: 80
#             - name: health
#               containerPort: 81
#           resources:
#             limits:
#               cpu: 0.2
#               memory: 10Mi
#           livenessProbe:
#             httpGet:
#               path: /healthz
#               port: 81
#               scheme: HTTP
#             initialDelaySeconds: 5
#             periodSeconds: 15
#             timeoutSeconds: 5
#           readinessProbe:
#             httpGet:
#               path: /readiness
#               port: 81
#               scheme: HTTP
#             initialDelaySeconds: 5
#             timeoutSeconds: 1

kubectl create -f deployments/hello-green.yaml
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version
kubectl apply -f services/hello-green.yaml
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version

# blue-green rollback
kubectl apply -f services/hello-blue.yaml
curl -ks https://`kubectl get svc frontend -o=jsonpath="{.status.loadBalancer.ingress[0].ip}"`/version
