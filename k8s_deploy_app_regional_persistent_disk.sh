#### Deploy applications with Regional Persistant Disks, in multi-zone Kubernetes.
#### Each zone has Kubernetes Master(s) and Nodes

# key concept: Kebernetes StorageClass resource across replicated zones
# so that deleteing a node won't bring down application

export CLUSTER_VERSION=$(gcloud container get-server-config --region=us-west1 --format='value(validMasterVersions[0])')
export CLOUDSDK_CONTAINER_USE_V1_API_CLIENT=false

# create a cluster in defined zones
gcloud container clusters create repd \
    --cluster-version=${CLUSTER_VERSION} \
    --machine-type=n1-standard-4 \
    --region=us-west1 \
    --num-nodes=1 \
    --node-locations=us-west1-a,us-west1-b,us-west1-c

# install Helm
curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

# init Helm
kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-cluster-rule \
  --clusterrole=cluster-admin \
  --serviceaccount=kube-system:tiller
helm init --service-account=tiller
until (helm version --tiller-connection-timeout=1 >/dev/null 2>&1); do echo "Waiting for tiller install..."; sleep 2; done && echo "Helm install complete"


# create Kubernetes StorageClass that is used by the regional persistant disk
kubectl apply -f - <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: repd-west1-a-b-c
provisioner: kubernetes.io/gce-pd
parameters:
  type: pd-standard
  replication-type: regional-pd
  zones: us-west1-a, us-west1-b, us-west1-c
EOF

kubectl get storageclass
# in comparation to standard StorageClass, the above repd-west1-a-b-c StorageClass is capable of provisioning PersistentVolume that are replicated across the 3 zones.

# create a PersistentVolumeClaim(PVC) for MariaDB, using standard StorageClass 
kubectl apply -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: data-wp-repd-mariadb-0
  namespace: default
  labels:
    app: mariadb
    component: master
    release: wp-repd
spec:
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 8Gi
  storageClassName: standard
EOF

# create a PersistentVolumeClaim(PVC) for WordPress, using repd-west1-a-b-c StorageClass
kubectl apply -f - <<EOF
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: wp-repd-wordpress
  namespace: default
  labels:
    app: wp-repd-wordpress
    chart: wordpress-5.7.1
    heritage: Tiller
    release: wp-repd
spec:
  accessModes:
    - ReadOnlyMany
  resources:
    requests:
      storage: 200Gi
  storageClassName: repd-west1-a-b-c
EOF

# list the available PVCs
kubectl get persitentvolumeclaims
# from the output, you can see two diffent StorageClass. With the PVCs, persistent disks can be created later.


# deploy WordPress
helm install --name wp-repd \
  --set smtpHost= --set smtpPort= --set smtpUser= \
  --set smtpPassword= --set smtpUsername= --set smtpProtocol= \
  --set persistence.storageClass=repd-west1-a-b-c \
  --set persistence.existingClaim=wp-repd-wordpress \
  --set persistence.accessMode=ReadOnlyMany \
  stable/wordpress

  kubectl get pods

# wait for LoadBalancer's external IP
  while [[ -z $SERVICE_IP ]]; do SERVICE_IP=$(kubectl get svc wp-repd-wordpress -o jsonpath='{.status.loadBalancer.ingress[].ip}'); echo "Waiting for service external IP..."; sleep 2; done; echo http://$SERVICE_IP/admin

# wait for the persistent disk to be created
while [[ -z $PV ]]; do PV=$(kubectl get pvc wp-repd-wordpress -o jsonpath='{.spec.volumeName}'); echo "Waiting for PV..."; sleep 2; done

kubectl describe pv $PV

# WordPress URL
echo http://$SERVICE_IP/admin


# user name and password to log in WordPress
cat - <<EOF
Username: user
Password: $(kubectl get secret --namespace default wp-repd-wordpress -o jsonpath="{.data.wordpress-password}" | base64 --decode)
EOF



#### Zone failure

# Obtain current node of the WordPress pod
#NODE=$(kubectl get pods -l app=wp-repd-wordpress -o jsonpath='{.items..spec.nodeName}')
NODE=$(kubectl get pods -l app.kubernetes.io/instance=wp-repd -o jsonpath='{.items..spec.nodeName}')
ZONE=$(kubectl get node $NODE -o jsonpath="{.metadata.labels['failure-domain\.beta\.kubernetes\.io/zone']}")
IG=$(gcloud compute instance-groups list --filter="name~gke-repd-default-pool zone:(${ZONE})" --format='value(name)')
echo "Pod is currently on node ${NODE}"
echo "Instance group to delete: ${IG} for zone: ${ZONE}"

# or verify with
# kubectl get pods -o wide -l app=wp-repd-wordpress
  kubectl get pods -o wide -l app.kubernetes.io/instance=wp-repd

# delete the instance group for the node where WordPress pod is running. Click "Y" to delete
# (can't directly delete the instances in the IG because the instances are managed by the group)
gcloud compute instance-groups managed delete ${IG} --zone ${ZONE}
# failure occured. Kubenetes migrates the pod to a node in another zone
# the deleted instance group is not automatically re-created.

# verify WordPress pod and persistent volume are in other zone
# kubectl get pods -o wide -l app=wp-repd-wordpress
  kubectl get pods -o wide -l app.kubernetes.io/instance=wp-repd
# verify app is still running
echo http://$SERVICE_IP/admin
