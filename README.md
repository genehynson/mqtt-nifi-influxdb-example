## MQTT + Apache NiFi + InfluxDB Example

Send data from an MQTT broker to InfluxDB via Apache NiFi. 

### Setup

Run NiFi with InfluxDB 2.0 processor plugin:
1. Clone this repo
1. `docker build -f ./Dockerfile.nifi . -t influxdb/nifi:latest`
1. Just run NiFi: `docker run -p 8443:8443 influxdb/nifi:latest ../scripts/start.sh`
1. Or, run NiFi + Mosquitto: `docker-compose up` - this will start NiFi and Mosquitto broker
1. Open NiFi by visiting https://localhost:8443/nifi - click "allow unsafe"
1. Enter username & password found in the console output.

Use the `MQTT-to-InfluxDB.xml` template:
1. In the NiFi GUI, drag a "Template" object to the board and select the "MQTT-to-InfluxDB" template.
2. Finish configuring the InfluxDB output processor by adding your API Token. To set the token, do:
  - Right click "PutInfluxDatabaseRecord_2" and click Configure
  - Click Properties and update Bucket and Organization with your bucket name and orgID. 
  - Then, click the --> arrow to the right of "StandardInfluxDatabaseService_2"
  - Click the gear icon next to "StandardInfluxDatabaseService_2"
  - Paste your token next to "InfluxDB Access Token".
  - Make sure to clean the lighting bolt next to both "StandardInfluxDatabaseService_2" and "InfluxLineProtocolReader" to start these services.
  - Click Apply/OK to dismiss all popup windows.
3. Press play!

From your MQTT client, connect to the Mosquitto broker with `tcp://localhost:1883` and publish to topic `/test` with body `mqtt,mytag=tagvalue myfield="fieldvalue"`. You should see these messages written to your InfluxDB instance in the bucket you previously specified.

### TODO:
- figure out how to add the template automatically by importing the `flow.xml.gz` file. This will require setting the `nifi.properties` file so the sensitive keys can be encrypted/decrypted successfully. I can't seem to replace these files at `influxdb/nifi` image build time without running into issues when NiFi starts.
- convert string values to Line Protocol with NiFi
- run multiple flows in one flow file