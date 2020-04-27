#### memcached deployment

export PROJECT_ID=$(gcloud config list project --format json| grep project | awk -F '"' '{print $4}')
export APP_REGION="us-central"
export APP_ZONE="us-central1-f"
# create a cluster
gcloud container clusters create demo-cluster --num-nodes=3 --zone=$APP_ZONE

# download Helm
cd ~
wget https://kubernetes-helm.storage.googleapis.com/helm-v2.14.0-linux-amd64.tar.gz
mkdir helm-v2.14.0
tar xvzf helm-v2.14.0-linux-amd64.tar.gz -C helm-v2.14.0
export PATH="$HOME/helm-v2.14.0/linux-amd64:$PATH"

# create a service acount with cluster admin role for Tiller
kubectl create serviceaccount tiller --namespace=kube-system
kubectl create clusterrolebinding tiller \
--clusterrole=cluster-admin \
--serviceaccount=kube-system:tiller

# Init Tiller and update available charts
helm init --serviceaccount=tiller
helm repo update

# Install memcached Helm chat
helm install stable/memcached --name mycache --set replicaCount=3
