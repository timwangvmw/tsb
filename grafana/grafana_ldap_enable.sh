#!/bin/bash
## Genernal Variables
KUBECTL_CMD="/bin/kubectl"
JQ_CMD="/bin/jq"
TMP_FILE="/tmp/grafa.tmp"
GRAFANA_NAMESPACE="tanzu-system-dashboards"
## Interactive Variables 
LDAP_CA_CERT_PATH=""
LDAP_HOST=""
LDAP_PORT=""
BIND_DN=""
BIND_PASSWORD=""
SEARCH_BASE_DN=""
SEARCH_FILTER=""
ATTR_USERNAME=""
ATTR_EMAIL=""
ATTR_MEMBEROF=""
GROUP_CONFIG="n"
SEARCH_GROUP_BASE_DN=""
SEARCH_GROUP_FILTER=""
SEARCH_GROUP_FILTER_USER_ATTR=""
GRAFANA_CONFIG_MAP_PATH="/tmp/ldap.toml"


${KUBECTL_CMD} get packageinstalls -A --no-headers | grep -i grafana.tanzu.vmware.com | head -n 1  > ${TMP_FILE}
if [ "$(cat ${TMP_FILE})" == "" ]; then
   echo "[ERROR] The grafana not installed for cluster."
   rm -f ${TMP_FILE}
   exit 1
fi


## LDAP Information
echo -n "LDAP CA CERT PATH(ex: /etc/pki/ca-trust/source/anchors/harca.crt): "
read LDAP_CA_CERT_PATH
echo -n "LDAP HOST (ex: ldap.har.lab.com.tw): "
read LDAP_HOST
echo -n "LDAP PORT(ex: 636): "
read LDAP_PORT
## Query Information
echo -n "BIND DN(ex: cn=admin,dc=har,dc=lab,dc=com,dc=tw): "
read BIND_DN
echo -n "BIND PASSWORD: "
read BIND_PASSWORD
## Search Information
echo -n "BASE DN(ex: dc=har,dc=lab,dc=com,dc=tw): "
read SEARCH_BASE_DN
echo -n "SEARCH FILTER(ex: (objectClass=inetOrgPerson)): "
read SEARCH_FILTER
## Server Mapping 
echo -n "ATTRIBUTES FOR USERNAME(ex: cn): "
read ATTR_USERNAME
echo -n "ATTRIBUTES FOR EMAIL(ex: email): "
read ATTR_EMAIL
echo -n "ATTRIBUTES FOR MEMBEROF(ex: cn): "
read ATTR_MEMBEROF
echo ""
echo -n "Do you want to configurate the group search? (y/n):"
read GROUP_CONFIG
## Group Search Information
if [ "${GROUP_CONFIG}" == "y" ]; then   
   echo -n "GROUP BASE DN(ex: dc=har,dc=lab,dc=com,dc=tw): "
   read SEARCH_GROUP_BASE_DN
   echo -n "GROUP SEARCH FILTER(ex: (objectClass=posixGroup)): "
   read SEARCH_GROUP_FILTER
   echo -n "GROUP SEARCH FILTER USER ATTRIBUTES(ex: gidNumber): "
   read SEARCH_GROUP_FILTER_USER_ATTR
elif [ "${GROUP_CONFIG}" == "n" ]; then
   echo "[INFO] Pass the group configuration"
else
   echo "[ERROR] Unknown input. Exit the script."
   rm -f ${TMP_FILE}
   exit 1
fi
echo 
echo "[INFO] LDAP Information"
echo -e "\t- CA FILE: ${LDAP_CA_CERT_PATH}"
echo -e "\t- LDAP HOST: ${LDAP_HOST}"
echo -e "\t- LDAP PORT: ${LDAP_PORT}"
echo "[INFO] LDAP BIND Information"
echo -e "\t- BIND DN: ${BIND_DN}"
echo -e "\t- BIND PASSWORD: ${BIND_PASSWORD}"
echo "[INFO] LDAP Search Information"
echo -e "\t- BASE DN: ${SEARCH_FILTER}"
echo -e "\t- SEARCH FILTER: ${SEARCH_FILTER}"
if [ "${GROUP_CONFIG}" == "y" ]; then
   echo -e "\t- GROUP BASE DN: ${SEARCH_GROUP_BASE_DN}"
   echo -e "\t- GROUP SEARCH FILTER: ${SEARCH_GROUP_FILTER}"
   echo -e "\t- GROUP SEARCH FILTER USER ATTR: ${SEARCH_GROUP_FILTER_USER_ATTR}"
fi
echo "[INFO] Server Attributes Information"
echo -e "\t- USERNAME: ${ATTR_USERNAME}"
echo -e "\t- EMAIL: ${ATTR_EMAIL}"
echo -e "\t- MEMBEROF: ${ATTR_MEMBEROF}"

echo ""
echo -n "All of above data is correct? Enter "y" to keep process (y/n):"
read PROCESS
## Group Search Information
if [ "${PROCESS}" == "y" ]; then   
   echo "[INFO] Ready to generating the ldap.toml on /tmp"
elif [ "${PROCESS}" == "n" ]; then
   echo "[INFO] The data seens like wrong. Exit the program."
   rm -f ${TMP_FILE}
   exit 0
else
   echo "[ERROR] Unknown input. Exit the script."
   rm -f ${TMP_FILE}
   exit 1
fi

echo "[[servers]]"                                                                  > ${GRAFANA_CONFIG_MAP_PATH}
echo "host = \"${LDAP_HOST}\""                                                     >> ${GRAFANA_CONFIG_MAP_PATH}
echo "port = ${LDAP_PORT}"                                                         >> ${GRAFANA_CONFIG_MAP_PATH}
echo "use_ssl = false"                                                             >> ${GRAFANA_CONFIG_MAP_PATH}
echo "start_tls = false"                                                           >> ${GRAFANA_CONFIG_MAP_PATH}
#echo "ssl_skip_verify = true"                                                      >> ${GRAFANA_CONFIG_MAP_PATH}
#echo "root_ca_cert = \"/var/run/secrets/ldap.crt\""                                >> ${GRAFANA_CONFIG_MAP_PATH}
echo                                                                               >> ${GRAFANA_CONFIG_MAP_PATH}
echo "bind_dn = \"${BIND_DN}\""                                                    >> ${GRAFANA_CONFIG_MAP_PATH}
echo "bind_password = \"${BIND_PASSWORD}\""                                        >> ${GRAFANA_CONFIG_MAP_PATH}
echo                                                                               >> ${GRAFANA_CONFIG_MAP_PATH}
echo "search_filter = \"${SEARCH_FILTER}\""                                        >> ${GRAFANA_CONFIG_MAP_PATH}
echo "search_base_dns = [\"${SEARCH_BASE_DN}\"]"                                   >> ${GRAFANA_CONFIG_MAP_PATH}
echo                                                                               >> ${GRAFANA_CONFIG_MAP_PATH}
if [ "${GROUP_CONFIG}" == "y" ]; then
  echo "group_search_filter = \"${SEARCH_FILTER}\""                                >> ${GRAFANA_CONFIG_MAP_PATH}
  echo "group_search_base_dns = [\"${SEARCH_GROUP_BASE_DN}\"]"                     >> ${GRAFANA_CONFIG_MAP_PATH}
  echo "group_search_filter_user_attribute = \"${SEARCH_GROUP_FILTER_USER_ATTR}\"" >> ${GRAFANA_CONFIG_MAP_PATH}
fi
echo "[servers.attributes]"                                                        >> ${GRAFANA_CONFIG_MAP_PATH}
echo "name = \"givenName\""                                                        >> ${GRAFANA_CONFIG_MAP_PATH}
echo "surname = \"sn\""                                                            >> ${GRAFANA_CONFIG_MAP_PATH}
echo "username = \"${ATTR_USERNAME}\""                                             >> ${GRAFANA_CONFIG_MAP_PATH}
echo "member_of = \"${ATTR_MEMBEROF}\""                                            >> ${GRAFANA_CONFIG_MAP_PATH}
echo "email =  \"${ATTR_EMAIL}\""                                                  >> ${GRAFANA_CONFIG_MAP_PATH}

echo ""
echo ""
## Retrive the grafana package info
NAMESPACE=$(cat ${TMP_FILE} | awk '{print $1}')
GRAFANA_PKG_NAME=$(cat ${TMP_FILE} | awk '{print $2}')
echo "[INFO] Ready to paused the packages for grafana: ${GRAFANA_PKG_NAME} in namespace: ${NAMESPACE}" > /dev/null
${KUBECTL_CMD} patch packageinstalls ${GRAFANA_PKG_NAME} -n ${NAMESPACE} --type merge -p '{"spec": {"paused": true}}' 



## Config the certificates and configs
echo "[INFO] Ready to create the configmap for Tanzu Grafana Packages"
${KUBECTL_CMD} create configmap custom-ldap-config --from-file=${GRAFANA_CONFIG_MAP_PATH} -n ${GRAFANA_NAMESPACE}  > /dev/null
#echo "[INFO] Ready to create the ldap secrets for Tanzu Grafana Packages"
#${KUBECTL_CMD} create secret generic custom-ldap-ca-cert --from-file=ldap.crt=${LDAP_CA_CERT_PATH} -n ${GRAFANA_NAMESPACE}  > /dev/null
#echo "[INFO] Ready to path the volumeMounts ldap certificate for Tanzu Grafana Packages deployment"
#${KUBECTL_CMD} patch deployment grafana -n ${GRAFANA_NAMESPACE}  --type json -p='[{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"secret":{"secretName": "custom-ldap-ca-cert"},"name": "custom-ldap-ca-cert"}}]'
echo "[INFO] Ready to path the volumeMounts ldap config for Tanzu Grafana Packages deployment"
${KUBECTL_CMD} patch deployment grafana -n ${GRAFANA_NAMESPACE}  --type json -p='[{"op": "add", "path": "/spec/template/spec/volumes/-", "value": {"configMap":{"defaultMode": 420,"name": "custom-ldap-config"},"name": "custom-ldap-config"}}]'
#echo "[INFO] Ready to path the volumes for ldap certificate for Tanzu Grafana Packages deployment"
#${KUBECTL_CMD} patch deployment grafana -n ${GRAFANA_NAMESPACE}  --type json -p='[{"op": "add", "path": "/spec/template/spec/containers/1/volumeMounts/-", "value": {"mountPath": "/var/run/secrets/ldap.crt", "name": "custom-ldap-ca-cert", "subPath": "ldap.crt"}}]'
echo "[INFO] Ready to path the volumes for ldap config for Tanzu Grafana Packages deployment"
${KUBECTL_CMD} patch deployment grafana -n ${GRAFANA_NAMESPACE}  --type json -p '[{"op": "add", "path": "/spec/template/spec/containers/1/volumeMounts/-", "value": {"mountPath": "/etc/grafana/ldap.toml", "name": "custom-ldap-config", "subPath": "ldap.toml"}}]'

echo "[INFO] Retrive the configmap for grafana"
${KUBECTL_CMD} get cm -n tanzu-system-dashboards  grafana -o jsonpath='{.data.grafana\.ini}' > /tmp/grafana-cm.tmp
IS_CONFIGED=0
if [ $(cat /tmp/grafana-cm.tmp | grep "auth.ldap" | wc -l) -ne 0 ]; then IS_CONFIGED=1 ; fi
if [ ${IS_CONFIGED} -eq 0 ]; then
   echo "[INFO] Ready to configure the default configmap for grafana"
   echo ""                                         >> /tmp/grafana-cm.tmp
   echo "[auth.ldap]"                              >> /tmp/grafana-cm.tmp 
   echo "enabled = true"                           >> /tmp/grafana-cm.tmp 
   echo "config_file = /etc/grafana/ldap.toml"     >> /tmp/grafana-cm.tmp 
   echo "allow_sign_up = true"                     >> /tmp/grafana-cm.tmp 
   echo "skip_org_role_sync = true"                >> /tmp/grafana-cm.tmp 
   cat /tmp/grafana-cm.tmp | while read line; do echo "\n${line}"; done >> /tmp/grafana-cm.tmp.new
   sed -i 's/\\n\[analytics/\[analytics/g' /tmp/grafana-cm.tmp.new
   GRFANA_NEW_CM="$(cat /tmp/grafana-cm.tmp.new | tr -d '\r\n')"
   echo "[INFO] Ready to patch the configmap."
   echo "[INFO] Configmap Data values:"
   echo "    ${GRFANA_NEW_CM}"
   ${KUBECTL_CMD} patch cm grafana -n tanzu-system-dashboards --type merge -p "{\"data\":{\"grafana.ini\":\"${GRFANA_NEW_CM}\"}}"
else
   echo "[PASS] Default grafana configmap is configured. Pass the configuration"
fi

rm -f ${TMP_FILE}
rm -f /tmp/grafana-cm.tmp /tmp/grafana-cm.tmp.new
exit 0
