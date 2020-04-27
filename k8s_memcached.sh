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
helm init --service-account=tiller
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
/sbin/apk update
/sbin/apk add python
/sbin/apk add py-pip
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
    # exit



#### Mcrouter - connection pooling. For those cases of too many connections
# delete previous Helm deploy
helm delete mycache --purge
# deploy new Helm chart that includes memcache and mcrouter
helm install stable/mcrouter --name=mycache --set memcached.replicaCount=3

# test the deployment
MCROUTER_POD_IP=$(kubectl get pods -l app=mycache-mcrouter -o jsonpath="{.items[0].status.podIP}")
kubectl run -it alpine --rm --image=alpine:3.6 --restart=Never telnet $MCROUTER_POD_IP 5000
# inside telnet prompt:
    #   store a key
        #   set anotherkey 0 0 15
        #   hello Mcrouter
        #   get anotherkey
    #   VALUE anotherkey 0 15
        #   hello Mcrouter
        #   END
        #   quit



#### Reduce latency
# need 3 points to reduce latency
# 1. One Mcrouter proxy pod for each node (and usaually deploy with a DaemonSet Controller). The DaemonSet Controller will add/remove proxy pod as number of nodes changes
# 2. A hostPort value in the proxy container's Kubernetes parameters. That parameter makes the node listen to that hostPort and redirect traffic to the proxy.
# 3. Node name. Expose the node name as env variable inside the app pods by using the spec.env entry and selecting the spec.nodeName fieldRef value. 
# ( https://kubernetes.io/docs/tasks/inject-data-application/environment-variable-expose-pod-information/ )

# step 1 and 2 have been done by the Helm chart. step 3:
# when deploy and applicaiton, make sure env variable NODE_NAME is in the yaml file. such as:
cat <<EOF | kubectl create -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: sample-application-py
spec:
  replicas: 5
  template:
    metadata:
      labels:
        app: sample-application-py
    spec:
      containers:
        - name: python
          image: python:3.6-alpine
          command: [ "sh", "-c"]
          args:
          - while true; do sleep 10; done;
          env:
            - name: NODE_NAME
              valueFrom:
                fieldRef:
                  fieldPath: spec.nodeName
EOF

# verify the node name is exposed to each pod by looking into one of the app pods
POD=$(kubectl get pods -l app=sample-application-py -o jsonpath="{.items[0].metadata.name}")
kubectl exec -it $POD -- sh -c 'echo $NODE_NAME'
# output: gke-demo-cluster-default-pool-XXXXXXXX-XXXX

# then in Python code lines, can use the NODE_NAME env variable to locate the Mcrouter in the same node. Example:
    # import os
    # from pymemcache.client.base import Client

    # NODE_NAME = os.environ['NODE_NAME']
    # client = Client((NODE_NAME, 5000))
    # client.set('some_key', 'some_value')
    # result = client.get('some_key')
    # result
# output b'some value'

