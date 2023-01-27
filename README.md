# gerrit-support-scripts

The script `create-support-bundles.sh` allows you to automatically generate support bundles for
each Gerrit pod in a Kubernetes namespace. The script only includes pods that have the label
`app=gerrit` assigned.

## Folder structure

The script creates a `tar.gz` file per pod. Each of these files contains the following folder
structure and files:

```text
$ tree .
.
├── graphs
│   ├── activeConnections.png
│   ├── activeThreads.png
│   ├── cpu.png
│   ├── fileDescriptors.png
│   ├── gc.png
│   ├── httpHitsRate.png
│   ├── httpMeanTimes.png
│   ├── sqlHitsRate.png
│   ├── sqlMeanTimes.png
│   └── usedMemory.png
├── info
│   ├── cpu-memory.txt
│   ├── gerrit-site-disk-usage.txt
│   ├── libraries.txt
│   └── plugins.txt
├── threadsDump
│   └── threadsDump.txt
└── var
    ├── gerrit
    │   ├── etc
    │   │   ├── gerrit.config -> ../../mnt/etc/gerrit.config
    │   │   ├── healthcheck.config -> ../../mnt/etc/healthcheck.config
    │   │   ├── jgit.config -> ../../mnt/etc/jgit.config
    │   │   ├── ssh_host_ecdsa_384_key.pub
    │   │   ├── ssh_host_ecdsa_521_key.pub
    │   │   ├── ssh_host_ecdsa_key.pub
    │   │   ├── ssh_host_ed25519_key.pub
    │   │   └── ssh_host_rsa_key.pub
    │   └── logs
    │       ├── delete_log
    │       ├── error_log
    │       ├── error_log.2023-01-15.gz
    │       ├── gc_log
    │       ├── gc_log.2023-01-15.gz
    │       ├── httpd_log
    │       ├── httpd_log.2023-01-15.gz
    │       ├── message_log
    │       ├── message_log.2023-01-13.gz
    │       ├── project_version_log
    │       ├── project_version_log.2023-01-13.gz
    │       ├── sharedref_log
    │       ├── sharedref_log.2023-01-13.gz
    │       ├── sshd_log
    │       └── sshd_log.2023-01-11.gz
    └── mnt
        └── etc
            ├── gerrit.config
            ├── healthcheck.config
            └── jgit.config
```

## Sample run

In the following example support bundles for the following 3 pods will be created.

```text
$ kubectl get pod
NAME       READY   STATUS    RESTARTS   AGE
gerrit-0   13/13   Running   0          37m
gerrit-1   13/13   Running   0          36m
gerrit-2   13/13   Running   0          36m

$ ./create-support-bundles.sh

SUPPORT-BUNDLE-GENERATOR

Make sure to do the following steps first:

1. visit Gerrit via the browser
2. log in via sso
3. copy the cookie "GerritAccount"

Kubernetes clusters: my-kubernetes-cluster
Kubernetes namespace [gerrit]:
Output location [/tmp/gerrit_2023-01-27_12-45]:
GerritAccount cookie: aSceprrTb8PhxPCZtMUKXAsLoZl4x-X5ZW

Cluster: my-kubernetes-cluster

Switched to context "my-kubernetes-cluster".

Creating support bundle for gerrit-0 ...

Adding config and logs ...
Getting system info ...
Getting javamelody graphs ...
Getting javamelody threads dump ...
Zipping archive ...
Downloading support bundle for gerrit-0 ...
tar: Removing leading `/' from member names
Successfully saved support bundle for gerrit-0

Creating support bundle for gerrit-1 ...

Adding config and logs ...
Getting system info ...
Getting javamelody graphs ...
Getting javamelody threads dump ...
Zipping archive ...
Downloading support bundle for gerrit-1 ...
tar: Removing leading `/' from member names
Successfully saved support bundle for gerrit-1

Creating support bundle for gerrit-2 ...

Adding config and logs ...
Getting system info ...
Getting javamelody graphs ...
Getting javamelody threads dump ...
Zipping archive ...
Downloading support bundle for gerrit-2 ...
tar: Removing leading `/' from member names
Successfully saved support bundle for gerrit-2

Support bundles saved to /tmp/gerrit_2023-01-27_12-45
```
