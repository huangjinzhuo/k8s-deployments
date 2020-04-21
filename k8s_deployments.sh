# RollingUpdate, Canary, Blue/Green Deployments on Kubernetes


git clone https://github.com/googlecodelabs/orchestrate-with-kubernetes.git
cd orchestrate-with-kubernetes/kubernetes

gcloud config set compute/zone us-central1-a
gcloud container clusters create bootcamp --num-nodes 5 --scopes "https://www.googleapis.com/auth/source.read_write,storage-rw"

kubectl explain deployment
kubectl explain deployment --recursive
kubectl explain deployment.metadata.name

sudo sed "s/auth:1.0.0/auth:2.0.0/g" deployments/auth.yaml

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

# Canary Deployment
#
# spec:
#   strategy:
#   type: Canary
#   canaryUpdate:
    

kubectl scale deployment xxxxx --replicas=6
kubectl autoscale deployment xxxxx --min=6 --max=10 --cpu-percent=70
