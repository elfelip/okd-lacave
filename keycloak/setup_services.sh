CLUSTER_NAME=acid-keycloak-cluster
NAMESPACE=keycloak
PATCH={\"spec\":{\"selector\":{\"application\":\"spilo\",\"cluster-name\":\"${CLUSTER_NAME}\",\"spilo-role\":\"master\"}}}
kubectl patch service ${CLUSTER_NAME} -n ${NAMESPACE} -p ${PATCH}
oc adm policy add-scc-to-group anyuid system:authenticated

PGPASSWORD=$(kubectl get secret keycloak-user.${CLUSTER_NAME}.credentials.postgresql.acid.zalan.do -o 'jsonpath={.data.password}' -n ${NAMESPACE} | base64 -d)

echo $PGPASSWORD