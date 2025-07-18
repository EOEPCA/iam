# Maintenance

This chapter comprises administrative and remedial activities to be
performed on a running IAM BB instance.

## Troubleshooting

This section describes some potential problems that might occur
and procedures to remediate them. 

### Repairing unstable APISIX persistence

Under the hood, APISIX uses etcd as its persistence. Though etcd is quite
stable in general, we observed occasional problems with it in our
reference environment. The typical problem was that one of the nodes of
the three-node etcd cluster became defunct and crashed repeatedly.
This results in bad performance and incidental errors when accessing
APISIX.

It would be possible to replace the defunct node with a new one, e.g. as described
[here](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#replacing-a-failed-etcd-member).
However, the APISIX persistence can be rebuilt from Kubernetes resources
and so it is a safe alternative to drop it and recreate it from scratch.
This can be done as follows:

* Rescale the stateful set that controls etcd (typically called `apisix-etcd`
  or `iam-apisix-etcd`, depending how APISIX is installed) to 0, which causes
  all etcd nodes to be shut down. APISIX itself is affected by this and is
  not fully functional any more, but it still continues serving
  connections based on the information in its cache. So this does not
  interrupt the service as long as the APISIX gateway pod keeps running.
* Delete the PVCs that are associated with the etcd nodes. They are typically
  called `data-apisix-etcd-n` where `n` is a number between 0 and 2.
* Now rescale the stateful set back to 3. Make sure that
  `ETCD_INITIAL_CLUSTER_STATE` is set to `new` in order to ensure that
  etcd actually rebuilds the cluster.
* During the next synchronization, the ingress controller should now update
  the persistence to the state represented by the K8s resources. If you do
  not want to wait for this to happen, you may restart the ingress
  controller pod to trigger an immediate synchronization.

Operations should not be interrupted directly by this procedure. However,
there is an increased risk of service interruption between shutting down
the etcds and resynchronizing with K8s resources.

### APISIX Ingress Controller does not synchronize resources

When deploying APISIX, the APISIX Ingress Controller
may be ready and try to reach the APISIX gateway before it is
completely up. As documented
[here](https://github.com/apache/apisix-ingress-controller/issues/1980),
this may cause the ingress controller to get stuck during initialization
and not do its job. The ingress controller pod, however, still looks
healthy at a first glance.

If you notice that resource synchronization does not take place
though the ingress controller pod looks good, you should check its
logs and maybe restart it. The restart should usually solve the
problem, provided that the APISIX gateway is available and working.

### APISIX Route does not get into effect

APISIX only accepts routes that are correct in the sense that all
referenced services and service ports actually exist at the
time when the route is created or updated. On the Kubernetes level,
however, incorrect route definitions can be applied without getting
an error.

Obviously, the ingress controller is not able to synchronize such
incorrect route definitions. It handles this by logging an error message
like `translation/apisix_route.go:621 ApisixRoute refers to non-existent
Service port` and retrying later, leaving the route unchanged until
the route definition or the referenced services are corrected.

If you observe that a change you made to a route definition
(`ApisixRoute` resource) does not get into effect, you may consult
the APISIX Ingress Controller logs and search for error messages like
the one stated above. If there are such messages, your route definition
is probably incorrect. Unfortunately the message typically only mentions
the namespace and port number, but no the affected service, so you need
to figure it out yourself.

Note that routes are only checked for correctness when they are created
or updated. If a service referenced by an already configured route
is modified in an incompatible way, only the reference to this service
is affected while other subroutes may still continue working.

### APISIX Route gets broken after update of referenced secret

The plugin sections of APISIX Routes may reference secrets that contain
further configuration details like client secrets. The APISIX Ingress
Controller does *not* monitor these secrets.

This means that changes made to such secrets only get into effect when
the referencing route changes and is resynchronized. One way to trigger
a resynchronization is to manually edit the route.

Note that changes to the secrets are not necessarily performed
manually, but can also occur implicitly when a `helm upgrade` is
executed in conjunction with automatic generation of secrets using Helm
random functions or if automated secret rotation is configured using tools
like `kubernetes-secret-generator`.
