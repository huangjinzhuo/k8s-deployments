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

# discovering memcached endpoints
kubectl get services mycache-memcached -o jsonpath="{.spec.clusterIP}" ; echo
# output None because the service was deployed as a headless(no clusterIP) service.

# retrieve the endpoints' IP addresses with one of the following two lines
kubectl get endpoints mycache-memcached
kubectl run -it alpine --rm --image=alpine:3.6 --restart=Never -- nslookup mycache-memcached.default.svc.cluster.local

# test the deployment by running a telnet on port 11211
kubectl run -it alpine --rm --image=alpine:3.6 --restart=Never \
telnet mycache-memcached-0.mycache-memcached.default.svc.cluster.local 11211
# inside telnet prompt:
    #   store a key
        #   set mykey 0 0 5
        #   hello
        #   get mykey
    #   VALUE mykey 0 5
        #   hello
        #   END
        #   quit

# use endpoints in Python. (need pymemcache library)
# start a shell and install pymemcache
kubectl run -it alpine --rm --image=alpine:3.6 --restart=Never sh
pip install pymemcache
python
# run the following in Python console(>>>)
    # import socket
    # from pymemcache.client.hash import HashClient
    # _, _, ips = socket.gethostbyname_ex('mycache-memcached.default.svc.cluster.local')
    # servers = [(ip, 11211) for ip in ips]
    # client = HashClient(servers, use_pooling=True)
    # client.set('mykey', 'hello')
    # client.get('mykey')
# output is b'hello'
    # exit()
