#!/bin/bash
# The default Node.js version is 0.10.40
# To use Node.js 0.12.7, uncomment the following line:
#export PATH=/opt/IBM/node-v0.12/bin:$PATH
# To use Node.js 4.2.2, uncomment the following line:
export PATH=/opt/IBM/node-v4.2/bin:$PATH
#npm install
echo $PWD
ls -al .

echo "env variables are:"
echo ${REPO_BRANCH}
echo ${APIC_URL_US}
echo ${SPACE}
echo ${CF_APP_NAME}
echo ${REGION}

echo " APIC URL IS  ${APIC_URL_US}"
echo "org is ${ORG} "

# apic api url
APIC_API_URL=api.${APIC_URL_US}

# install yaml
if [ ! -f ./yaml ]; then
    wget https://github.com/mikefarah/yaml/releases/download/1.5/yaml_linux_amd64 -O yaml
    chmod +x yaml
fi

set -x

#create cloudant service instance 
cf create-service cloudantNoSQLDB Lite hotels-events-db
# create a key for this service
cf create-service-key hotels-events-db for-api

# create api connect service
#cf create-service APIConnect Essentials hotels-apiconnect

# retrieve the URL - it contains credentials + API URL
CLOUDANT_URL=`cf service-key hotels-events-db for-api | grep \"url\" | awk -F '"' '{print $4}'`
CLOUDANT_DATABASE="eventsdb"
curl $CLOUDANT_URL/$CLOUDANT_DATABASE -X PUT
#ignore db already exists message

echo "Updating datasources.json with cloudant url"
CLOUDANT_URL=$(echo $CLOUDANT_URL | sed -e 's/\//\\\//g'  )
sed -i .bak  -e "s/\"url\":.*/\"url\":\"$CLOUDANT_URL\",/" server/datasources.json
cat server/datasources.json

# set orgs
CHARLST="[@|.|-|_]"
ORGS=$(echo $ORG|sed "s/$CHARLST//g")-$SPACE
ORGS=$(echo $ORGS|tr '[:upper:]' '[:lower:]')
echo "orgs is $ORGS"

# Configure APIC cli
echo -e "Start installing apiconnect cli"
npm install -g apiconnect
echo -e "completed installing apic cli"
echo "yes" | apic
echo "no" | apic

echo -e "Login and config set catalog.."
apic login -k ${BLUEMIX_API_KEY} -s ${APIC_URL_US}
apic config:set catalog=apic-catalog://${APIC_URL_US}/orgs/${ORGS}/catalogs/sb
apic organizations -s us.apiconnect.ibmcloud.com
#apic config:set app=apic-app://${APIC_URL_US}/orgs/${ORGS}/apps/$CF_APP_NAME
#apic apps:publish
cf push $CF_APP_NAME
./yaml w --inplace definitions/onboarding-event-api.yaml x-ibm-configuration.catalogs.sb.properties.runtime-url "https://${CF_APP_NAME}.mybluemix.net"
cat  definitions/onboarding-event-api.yaml


apic publish -o ${ORGS} -s ${APIC_URL_US} definitions/onboarding-event-api-product.yaml

