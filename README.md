## MQTT + Apache NiFi + InfluxDB Example

Stream data from multiple MQTT brokers to InfluxDB via Apache NiFi.
### Setup

TL;DR: 1) fill out `.env`, 2) run `make build`, 3) run `make start`

**Build NiFi image with InfluxDB 2.0 processor plugin:**
1. Clone this repo
1. Build influxdb/nifi image: `make build-nifi`
1. If you just want to run a blank NiFi: `docker run -p 8443:8443 influxdb/nifi:latest ../scripts/start.sh`
1. Import the MQTT-to-InfluxDB NiFi template to play around with streaming MQTT data to InfluxDB

**Start the end-to-end example with multiple MQTT brokers:**
1. Copy the `example.env` file to `.env` and fill it out.
1. Build the images with `make build`
1. Run `make start`
  - NiFi will take about 30 seconds to start. Run `make logs NODE=[service name]` to check the logs of the service (e.g. `make logs NODE=nifi`)
1. Check your InfluxDB instance - data should be flowing into your bucket!
1. Open NiFi by visiting https://localhost:8443/nifi - click "allow unsafe"
1. Enter username `admin` & password `nifipassword`
1. Run `make stop` when you want to shutdown the containers.

### Example Overview

So now that you have everything running, what exactly is going on here?

When you ran `make start` you started up several MQTT clients, a couple MQTT mosquitto brokers, and a single NiFi instance. After those continers came online, the nifi.bash script executed to automatically configure NiFi with process groups to subscribe to topics from our MQTT mosquitto brokers. Basically the MQTT clients are publishing messages to the MQTT brokers. NiFi is listening for those messages from the brokers and is sending them to InfluxDB.

Each of the MQTT clients are configured to send different data types to the brokers. One is sending Line Protcol, another is sending JSON, and the third is sending a simple string. The three process groups in NiFi are configured to accept a specific data type. This demonstrates that we can handle these various input types and convert them all to Line Protocol before sending the data to InfluxDB.

### What's in this repo
- Dockerfile.nifi: a dockerfile that is based on the Apache NiFi image bundled with the InfluxData processor plugin.
- Dockerfile.nifipoc: a dockerfile that contains the `nifi.bash` script to configure NiFi to communicate with our MQTT brokers
- docker-compose.yml: a docker compose file that contains the definition for the containers required in this example
- nifi.bash: a script that uses NiFi's APIs to configure process groups that communicate with our MQTT brokers
- nifi.http: if you install VSCode's REST Client extension, you can use this file to send example HTTP requests to NiFi
- MQTT-to-InfluxDB.xml: a NiFi template that's bundled in the `influxdb/nifi` image that provides a simple process group example to stream MQTT data to InfluxDB.