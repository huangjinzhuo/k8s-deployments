#### MongoDB in Kubernetes with Statefulsets
# to run a stateful databbase in a cluster of stateless VM nodes, we need a replicaset.
# replicaset makes sure datat is highly available and redundant:
# download MangoDB replicaset/sidecar
# dedploy StorageClass, headless service, and a statefulset.

# create a cluster
gcloud config set compute/zone us-central1-f
gcloud container clusters create hello-world

# download MangoDB replicaset/sidecar
git clone https://github.com/thesandlord/mongo-k8s-sidecar.git
cd ./mongo-k8s-sidecar/example/StatefulSet/

# create a StorageClass
cat googlecloud_ssd.yaml
# kind: StorageClass
# apiVersion: storage.k8s.io/v1beta1
# metadata:
#   name: fast
# provisioner: kubernetes.io/gce-pd
# parameters:
#   type: pd-ssd
kubectl apply -f googlecloud_ssd.yaml

# deploy headless service and StatefulSet
cat mongo-statefulset.yaml
# apiVersion: v1
# kind: Service
# metadata:
#   name: mongo
#   labels:
#     name: mongo
# spec:
#   ports:
#   - port: 27017
#     targetPort: 27017
#   clusterIP: None
#   selector:
#     role: mongo
# ---
# apiVersion: apps/v1beta1
# kind: StatefulSet
# metadata:
#   name: mongo
# spec:
#   serviceName: "mongo"
#   replicas: 3
#   template:
#     metadata:
#       labels:
#         role: mongo
#         environment: test
#     spec:
#       terminationGracePeriodSeconds: 10
#       containers:
#         - name: mongo
#           image: mongo
#           command:
#             - mongod
#             - "--replSet"
#             - rs0
#             - "--smallfiles"
#             - "--noprealloc"
#           ports:
#             - containerPort: 27017
#           volumeMounts:
#             - name: mongo-persistent-storage
#               mountPath: /data/db
#         - name: mongo-sidecar
#           image: cvallance/mongo-k8s-sidecar
#           env:
#             - name: MONGO_SIDECAR_POD_LABELS
#               value: "role=mongo,environment=test"
#   volumeClaimTemplates:
#   - metadata:
#       name: mongo-persistent-storage
#       annotations:
#         volume.beta.kubernetes.io/storage-class: "fast"
#     spec:
#       accessModes: [ "ReadWriteOnce" ]
#       resources:
#         requests:
#           storage: 100Gi


# use nano or other editor to remove the two lines: - "--smallfiles"       - "--noprealloc"
nano mongo-statefulset.yaml

# deploy headless(no load balancing) service, and statefulset
kubectl apply -f mongo-statefulset.yaml
kubectl get statefulset
kubectl get pods

# connect to the first replicaset memeber (mango-0)
kubectl exec -it mango-0 mongo

