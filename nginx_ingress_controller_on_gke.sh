#### NGINX Ingress Controller on GKE
#### NGINX advantages: Websockets, SSL Services, Session Persistence, JWTs validation.


# Create a cluster
gcloud config set compute/zone us-central1-a
gcloud container clusters create nginx-tutorial --num-nodes 2
# Install Helm client on PC/VM
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > install-helm.sh
chmod u+x install-helm.sh
./install-helm.sh --version v2.16.3
helm init
#Deploy Tiller on cluster after Service Account and Cluster Role Binding created.
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'  
helm init --service-account tiller --upgrade
kubectl get deployments -n kube-system


# Deploy an Ingress Resource for apps to use NGINX Ingress as a Controller
helm install --name nginx-ingress stable/nginx-ingress --set rbac.create=true
# the second service, nginx-ingress-default-backend. The default backend is a Service which handles all URL paths and hosts the NGINX controller. The default backend exposes two URLs:
# /healthz that returns 200
# / that returns 404
kubectl get service nginx-ingress-controller


# Deploy a web app and expose the deployment as a Service on port 8080
kubectl create deployment hello-app --image=gcr.io/google-samples/hello-app:1.0
kubectl expose deployment hello-app  --port=8080

# Config Ingress Resource to use NGINX Ingress Controller
# The Ingress Resource  determines which controller to utilize by setting with an annotation: kubernetes.io/ingress.class
cat > ingress-resource.yaml << EOF
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-resource
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /hello
        backend:
          serviceName: hello-app
          servicePort: 8080
EOF
kubectl apply -f ingress-resource.yaml
kubectl get ingress ingress-resource
# Wait to get the External IP Address. Notice that the external IPs are different for ingress-resource and nginx-ingress-controller 

# Test NGINX Ingress. Using a GCP L4 TCP/UDP Load Balancer frontend IP, and ensure it can access the web app.
http://external-ip-of-ingress-controller/healthz        # return 200 from default backend service
http://external-ip-of-ingress-controller/hello          # return hello page from hello service
http://external-ip-of-ingress-controller/               # return 404 from default backend service
http://external-ip-of-ingress-resource/hello            # page not reachable