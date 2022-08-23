# GCP Resource information


# Adding Disks

The section will detail adding a disk to a cluster installed on GCP. You may use [this link](https://kubebyexample.com/en/concept/persistent-volumes)
for a simple example using kubernetes. 

1. Begin by installing a cluster using openshift-install; an IPI configuration.
2. You will be able to view all machines, and machinesets and other resources in OC

```bash
oc get machinesets -A
```

3. Using the web console, create a Persistent Volume Claim (PVC).
3.1 Using the output from the openshift-install create cluster, grab the username, password, and url.
3.2 Open the URL and enter the information.
3.3 Go to Storage -> Persistent Volume Claims
3.4 Create a new PVC. You should now see resource in `oc`

```bash
oc get pvc -A
```

```bash
NAME                           CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
PVC-VOLUME-NAME                5Gi        RWO            Retain           Available           slow                    35m
```

```bash
NAME                                  STATUS    VOLUME   CAPACITY   ACCESS MODES   STORAGECLASS   AGE
PVC-VOLUME-NAME                       Pending                                      standard       28m
```

3.5 As above, you will notice that the PVC is `pending`. If you look at the websole where the
PVC was created and look at the `EVENTS`, it will say that a consumer is required before it can be configured.

4. Let's make a fake consumer

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: pv-deploy
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mypv
  template:
    metadata:
      labels:
        app: mypv
    spec:
      containers:
      - name: shell
        image: centos:7
        command:
        - "bin/bash"
        - "-c"
        - "sleep 10000"
        volumeMounts:
        - name: mypd
          mountPath: "/tmp/persistent"
      volumes:
      - name: mypd
        persistentVolumeClaim:
          claimName: PVC-VOLUME-NAME
```

4.1 Output the above into a file called deploy.yaml

5. Run `oc apply -f deploy.yaml`.

6. If you rerun the `oc get` you will see a `Bound` instead of `Pending`.

7. Visit GCP -> Disks, and you will see the new disk created. 