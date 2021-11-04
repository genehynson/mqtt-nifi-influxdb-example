#!/bin/bash
set -eu -o pipefail

#########
# This script configures NiFi to commnicate with 2 brokers
#########

### Variables

# The NiFi UI url
NIFI_UI_URL="https://nifi:8443/nifi"
# The NiFi API url
NIFI_URL="https://nifi:8443/nifi-api"
# The NiFi login username
NIFI_USERNAME="admin"
# The NiFi login password
NIFI_PASSWORD="nifipassword"
# JWT token for API requests
TOKEN=""
# The NiFi provided client-id
CLIENT_ID=""
# The ID of the highest level process group (aka the 'flow')
PROCESS_GROUP_FLOW_ID=""
# The ID of the created process group
PROCESS_GROUP_ID=""
# The ID of the created ConsumeMQTT processor
SOURCE_PROCESSOR_ID=""
# The ID of the created PutInfluxDB processor
DESTINATION_PROCESSOR_ID=""
# The ID of the created record reader controller service
INFLUX_RECORD_READER_ID=""
# The ID of the Influx controller service
INFLUX_CONTROLLER_SERVICE_ID=""
# The InfluxDB Org ID
INFLUX_ORG_ID=${INFLUX_ORG_ID:-""}
# The InfluxDB Bucket name
INFLUX_BUCKET_NAME=${INFLUX_BUCKET_NAME:-""}
# The InfluxDB API Token
INFLUX_API_TOKEN=${INFLUX_API_TOKEN:-""}
# The InfluxDB base URL
INFLUX_URL=${INFLUX_URL:-""}

### PART 0: Wait for NiFi to come online

while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "username=${NIFI_USERNAME}&password=${NIFI_PASSWORD}" "${NIFI_URL}/access/token" -k)" != "201" ]]; do sleep 5; done
echo "NiFi has started, let's begin..."

### PART 1: Login, get config IDs

# Get a JWT
TOKEN=$(curl -s -X POST -H "Content-Type: application/x-www-form-urlencoded" -d "username=${NIFI_USERNAME}&password=${NIFI_PASSWORD}" "${NIFI_URL}/access/token" -k)

# Get a Client ID
CLIENT_ID=$(curl -s -H "Authorization: Bearer ${TOKEN}" "${NIFI_URL}/flow/client-id" -k)

# Get processGroupFlowId
# TODO: find a better API to get this
resp=$(curl -s -H "Authorization: Bearer ${TOKEN}" "${NIFI_URL}/flow/templates" -k)
PROCESS_GROUP_FLOW_ID=$(echo ${resp} | jq  -r '.templates | .[0] | .template | .groupId')

createProcessGroup() {
    ### PART 2: Create new process group with processors

    PROCESSOR_GROUP_NAME=${1:-"Processor Group MQTT 1"}
    MQTT_BROKER_HOST=${2:-"mosquitto1"}
    MQTT_TOPIC=${3:-"/1"}

    echo "Creating $PROCESSOR_GROUP_NAME"

    # Create process group
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"component\":{\"name\":\"${PROCESSOR_GROUP_NAME}\",\"position\":{\"x\":647.5,\"y\":-299.5}}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_FLOW_ID}/process-groups" -k)
    PROCESS_GROUP_ID=$(echo ${resp} | jq -r '.id')

    # Create ConsumeMQTT processor
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"component\":{\"bundle\":{\"artifact\":\"nifi-mqtt-nar\",\"group\":\"org.apache.nifi\",\"version\":\"1.14.0\"},\"type\":\"org.apache.nifi.processors.mqtt.ConsumeMQTT\",\"name\":\"ConsumeMQTT\",\"position\":{\"x\":-232,\"y\":-72}}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_ID}/processors" -k)
    SOURCE_PROCESSOR_ID=$(echo ${resp} | jq -r '.id')

    # Create PutInfluxDB processor
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"component\":{\"bundle\":{\"artifact\":\"nifi-influx-database-nar\",\"group\":\"org.influxdata.nifi\",\"version\":\"1.13.0\"},\"type\":\"org.influxdata.nifi.processors.PutInfluxDatabaseRecord_2\",\"name\":\"PutInfluxDatabaseRecord_2\",\"position\":{\"x\":408,\"y\":-80}}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_ID}/processors" -k)
    DESTINATION_PROCESSOR_ID=$(echo ${resp} | jq -r '.id')

    # Link the ConsumeMQTT and PutInfluxDB processors
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"component\":{\"name\":\"\",\"source\":{\"id\":\"${SOURCE_PROCESSOR_ID}\",\"groupId\":\"${PROCESS_GROUP_ID}\",\"type\":\"PROCESSOR\"},\"destination\":{\"id\":\"${DESTINATION_PROCESSOR_ID}\",\"groupId\":\"${PROCESS_GROUP_ID}\",\"type\":\"PROCESSOR\"},\"selectedRelationships\":[\"Message\"],\"flowFileExpiration\":\"0 sec\",\"backPressureDataSizeThreshold\":\"1 GB\",\"backPressureObjectThreshold\":\"10000\",\"bends\":[],\"prioritizers\":[]}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_ID}/connections" -k)

    # Update ConsumeMQTT processor
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":3},\"component\":{\"id\":\"${SOURCE_PROCESSOR_ID}\",\"config\":{\"properties\":{\"Broker URI\":\"tcp:\\/\\/${MQTT_BROKER_HOST}:1883\",\"Client ID\":\"nifi\",\"Topic Filter\":\"${MQTT_TOPIC}\",\"Quality of Service(QoS)\":\"0\",\"Max Queue Size\":\"100\"}}}}"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/processors/${SOURCE_PROCESSOR_ID}" -k)

    ### PART 3: Create the Controller Services

    # Create InfluxLineProtocolReader service
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"disconnectedNodeAcknowledged\":false,\"component\":{\"type\":\"org.influxdata.nifi.serialization.InfluxLineProtocolReader\",\"bundle\":{\"group\":\"org.influxdata.nifi\",\"artifact\":\"nifi-influx-database-nar\",\"version\":\"1.13.0\"},\"name\":\"InfluxLineProtocolReader\"}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_ID}/controller-services" -k)
    INFLUX_RECORD_READER_ID=$(echo ${resp} | jq -r '.id')

    # Create the StandardInfluxDatabaseService_2 service
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":0},\"disconnectedNodeAcknowledged\":false,\"component\":{\"type\":\"org.influxdata.nifi.services.StandardInfluxDatabaseService_2\",\"bundle\":{\"group\":\"org.influxdata.nifi\",\"artifact\":\"nifi-influx-database-nar\",\"version\":\"1.13.0\"},\"name\":\"StandardInfluxDatabaseService_2\"}}"
    resp=$(curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/process-groups/${PROCESS_GROUP_ID}/controller-services" -k)
    INFLUX_CONTROLLER_SERVICE_ID=$(echo ${resp} | jq -r '.id')

    # Update the InfluxDB controller service
    json="{ \"revision\":{ \"clientId\":\"${CLIENT_ID}\", \"version\":0 }, \"component\":{ \"id\": \"${INFLUX_CONTROLLER_SERVICE_ID}\", \"properties\": { \"influxdb-token\": \"${INFLUX_API_TOKEN}\", \"influxdb-url\": \"${INFLUX_URL}\" } } }"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/controller-services/${INFLUX_CONTROLLER_SERVICE_ID}" -k)

    # Update the InfluxDB processor with the controller services
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":25},\"component\":{\"id\":\"${DESTINATION_PROCESSOR_ID}\",\"config\":{\"autoTerminatedRelationships\":[\"success\",\"failure\",\"retry\"],\"properties\":{\"influxdb-bucket\":\"${INFLUX_BUCKET_NAME}\",\"influxdb-org\":\"${INFLUX_ORG_ID}\",\"record-reader\":\"${INFLUX_RECORD_READER_ID}\",\"influxdb-service\":\"${INFLUX_CONTROLLER_SERVICE_ID}\"}}}}"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/processors/${DESTINATION_PROCESSOR_ID}" -k)

    ### PART 4: Start all the things

    echo "Starting $PROCESSOR_GROUP_NAME"

    # Start the InfluxLineProtocolReader controller service
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":2},\"disconnectedNodeAcknowledged\":false,\"state\":\"ENABLED\"}"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/controller-services/${INFLUX_RECORD_READER_ID}/run-status" -k)

    # Start the InfluxDB controller service
    json="{\"revision\":{\"clientId\":\"${CLIENT_ID}\",\"version\":2},\"disconnectedNodeAcknowledged\":false,\"state\":\"ENABLED\"}"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/controller-services/${INFLUX_CONTROLLER_SERVICE_ID}/run-status" -k)

    # Start the process group
    json="{\"id\":\"${PROCESS_GROUP_ID}\",\"state\":\"RUNNING\"}"
    resp=$(curl -s -X PUT -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" -d "${json}" "${NIFI_URL}/flow/process-groups/${PROCESS_GROUP_ID}" -k)
}

createProcessGroup "Process Group MQTT 1" "mosquitto1" "/1"

createProcessGroup "Process Group MQTT 2" "mosquitto2" "/2"

echo "Successfully created and started the process groups; exiting"