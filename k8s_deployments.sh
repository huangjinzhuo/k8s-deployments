RollingUpdate, Canary, Blue/Green Deployments on Kubernetes

git clone https://github.com/googlecodelabs/orchestrate-with-kubernetes.git
cd orchestrate-with-kubernetes/kubernetes

check out deployments/frontend.yaml file for configMap example
spec:
  containers:
    volumeMounts:
      - name: xxxx
        mountPath: xxxxxx
      -name: "tls-certs"
   volumes:
        - name: xxxxxxx
          secret:
            secretName: xxxx
        - name: "nginx-frontend-conf"
          configMap:
            name: "nginx-frontend-conf"
            items:
              - key: "frontend.conf"
                 path: "frontend.conf"

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
