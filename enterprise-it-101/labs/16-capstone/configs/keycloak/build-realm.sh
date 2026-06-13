#!/bin/bash
# TEMPORARY build script (not shipped) — run inside the keycloak container to
# construct the lab-corp realm, then export it. Delete after exporting.
set -e
KC=/opt/keycloak/bin/kcadm.sh
$KC config credentials --server http://localhost:8088 --realm master --user admin --password admin

echo "==> create realm lab-corp (explicit id so component parentId is deterministic)"
$KC create realms -s id=lab-corp -s realm=lab-corp -s enabled=true

echo "==> create AD LDAP user federation"
LDAP_ID=$($KC create components -r lab-corp -i \
  -s name=ad \
  -s providerId=ldap \
  -s providerType=org.keycloak.storage.UserStorageProvider \
  -s parentId=lab-corp \
  -s 'config.enabled=["true"]' \
  -s 'config.vendor=["ad"]' \
  -s 'config.connectionUrl=["ldaps://dc1.lab.corp:636"]' \
  -s 'config.bindDn=["cn=Administrator,cn=Users,dc=lab,dc=corp"]' \
  -s 'config.bindCredential=["P@ssw0rd1"]' \
  -s 'config.editMode=["READ_ONLY"]' \
  -s 'config.usersDn=["OU=Employees,DC=lab,DC=corp"]' \
  -s 'config.usernameLDAPAttribute=["sAMAccountName"]' \
  -s 'config.rdnLDAPAttribute=["cn"]' \
  -s 'config.uuidLDAPAttribute=["objectGUID"]' \
  -s 'config.userObjectClasses=["person, organizationalPerson, user"]' \
  -s 'config.searchScope=["2"]' \
  -s 'config.pagination=["true"]' \
  -s 'config.useTruststoreSpi=["always"]' \
  -s 'config.startTls=["false"]' \
  -s 'config.connectionPooling=["true"]' \
  -s 'config.importEnabled=["true"]' \
  -s 'config.syncRegistrations=["false"]' \
  -s 'config.batchSizeForSync=["1000"]' \
  -s 'config.fullSyncPeriod=["-1"]' \
  -s 'config.changedSyncPeriod=["-1"]' \
  -s 'config.validatePasswordPolicy=["false"]' \
  -s 'config.trustEmail=["true"]' \
  -s 'config.priority=["0"]')
echo "LDAP_ID=$LDAP_ID"

echo "==> create group-ldap-mapper"
$KC create components -r lab-corp \
  -s name=group-mapper \
  -s providerId=group-ldap-mapper \
  -s providerType=org.keycloak.storage.ldap.mappers.LDAPStorageMapper \
  -s parentId="$LDAP_ID" \
  -s 'config."groups.dn"=["CN=Users,DC=lab,DC=corp"]' \
  -s 'config."group.name.ldap.attribute"=["cn"]' \
  -s 'config."group.object.classes"=["group"]' \
  -s 'config."membership.ldap.attribute"=["member"]' \
  -s 'config."membership.attribute.type"=["DN"]' \
  -s 'config."membership.user.ldap.attribute"=["sAMAccountName"]' \
  -s 'config."user.roles.retrieve.strategy"=["LOAD_GROUPS_BY_MEMBER_ATTRIBUTE"]' \
  -s 'config.mode=["READ_ONLY"]' \
  -s 'config."groups.path"=["/"]' \
  -s 'config."memberof.ldap.attribute"=["memberOf"]' \
  -s 'config."preserve.group.inheritance"=["false"]'

echo "==> trigger full user sync"
$KC create "user-storage/$LDAP_ID/sync?action=triggerFullSync" -r lab-corp || echo "(user sync nonzero)"

echo "==> create OIDC client sample-app (fixed secret)"
CLIENT_ID=$($KC create clients -r lab-corp -i \
  -s clientId=sample-app \
  -s enabled=true \
  -s protocol=openid-connect \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=true \
  -s secret=capstone-sample-app-secret \
  -s 'redirectUris=["http://sample-app.lab.corp:8089/*"]' \
  -s 'webOrigins=["+"]')
echo "CLIENT_ID=$CLIENT_ID"

echo "==> add groups protocol mapper to the client"
$KC create "clients/$CLIENT_ID/protocol-mappers/models" -r lab-corp \
  -s name=groups \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-group-membership-mapper \
  -s 'config."claim.name"=["groups"]' \
  -s 'config."full.path"=["false"]' \
  -s 'config."id.token.claim"=["true"]' \
  -s 'config."access.token.claim"=["true"]' \
  -s 'config."userinfo.token.claim"=["true"]'

echo "==> DONE. LDAP_ID=$LDAP_ID CLIENT_ID=$CLIENT_ID"
