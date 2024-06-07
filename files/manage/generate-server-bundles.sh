#!/bin/bash

OUTPUT_FILE=$1

[[ -z "${OUTPUT_FILE}" ]] && echo "usage: generate-server-bundles.sh <output-file>" && exit 1
[[ -z "${MAS_INSTANCE_ID}" ]] && echo "Required MAS_INSTANCE_ID env var not found" && exit 1
[[ -z "${MAS_WORKSPACE_ID}" ]] && echo "Required MAS_WORKSPACE_ID env var not found" && exit 1

echo "OUTPUT_FILE ............ ${OUTPUT_FILE}"
echo "MAS_INSTANCE_ID  ....... ${MAS_INSTANCE_ID}"
echo "MAS_WORKSPACE_ID ....... ${MAS_WORKSPACE_ID}"

SB0_B64=$(echo -n '<?xml version="1.0" encoding="UTF-8"?>
<server description="new server '${MAS_WORKSPACE_ID}'-manage-d--sb0--asc--sn">
<featureManager>
<feature>jndi-1.0</feature>
<feature>wasJmsClient-2.0</feature>
<feature>jmsMdb-3.2</feature>
<feature>mdb-3.2</feature>
</featureManager>
    <jmsQueueConnectionFactory jndiName="jms/maximo/int/cf/intcf" connectionManagerRef="mifjmsconfact"><properties.wasJms remoteServerAddress="'${MAS_INSTANCE_ID}'-'${MAS_WORKSPACE_ID}'-jms.mas-'${MAS_INSTANCE_ID}'-manage.svc:7276:BootstrapBasicMessaging"/></jmsQueueConnectionFactory>
    <connectionManager id="mifjmsconfact" maxPoolSize="20"/>
    <jmsQueue jndiName="jms/maximo/int/queues/sqout"><properties.wasJms queueName="sqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/sqin"><properties.wasJms queueName="sqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqin"><properties.wasJms queueName="cqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqinerr"><properties.wasJms queueName="cqinerrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqout"><properties.wasJms queueName="cqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqouterr"><properties.wasJms queueName="cqouterrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notf"><properties.wasJms queueName="notfbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notferr"><properties.wasJms queueName="notferrbd"/></jmsQueue>
</server>
' | base64 -w0)


SB1_B64=$(echo -n '<?xml version="1.0" encoding="UTF-8"?>
<server description="new server '${MAS_WORKSPACE_ID}'-manage-d--sb1--asc--sn">
<featureManager>
<feature>jndi-1.0</feature>
<feature>wasJmsClient-2.0</feature>
<feature>jmsMdb-3.2</feature>
<feature>mdb-3.2</feature>
</featureManager>
    <jmsQueueConnectionFactory jndiName="jms/maximo/int/cf/intcf" connectionManagerRef="mifjmsconfact"><properties.wasJms remoteServerAddress="'${MAS_INSTANCE_ID}'-'${MAS_WORKSPACE_ID}'-jms.mas-'${MAS_INSTANCE_ID}'-manage.svc:7276:BootstrapBasicMessaging"/></jmsQueueConnectionFactory>
    <connectionManager id="mifjmsconfact" maxPoolSize="20"/>
    <jmsQueue jndiName="jms/maximo/int/queues/sqout"><properties.wasJms queueName="sqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/sqin"><properties.wasJms queueName="sqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqin"><properties.wasJms queueName="cqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqinerr"><properties.wasJms queueName="cqinerrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqout"><properties.wasJms queueName="cqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqouterr"><properties.wasJms queueName="cqouterrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notf"><properties.wasJms queueName="notfbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notferr"><properties.wasJms queueName="notferrbd"/></jmsQueue>
    <jmsActivationSpec id="maximomea/mboejb/JMSContQueueProcessor-1" maxEndpoints="5"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqin" maxConcurrency="5" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContQueueProcessor-2" maxEndpoints="1"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqinerr" maxConcurrency="1" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContOutQueueProcessor-1" maxEndpoints="5"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqout" maxConcurrency="5" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContOutQueueProcessor-2" maxEndpoints="1"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqouterr" maxConcurrency="1" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
</server>
' | base64 -w0)

SB2_B64=$(echo -n '<?xml version="1.0" encoding="UTF-8"?>
<server description="new server '${MAS_INSTANCE_ID}'-manage-d--sb2--asc--sn">

  <!-- Enable features -->
	<featureManager>
	  <feature>wasJmsSecurity-1.0</feature>
	  <feature>wasJmsServer-1.0</feature>
  </featureManager>
  <applicationManager autoExpand="true"/>
  <wasJmsEndpoint host="*" wasJmsSSLPort="7286" wasJmsPort="7276" />
  <messagingEngine>
	  <fileStore path="jms/jmsstore"/>
	  <queue id="sqoutbd" maintainStrictOrder="true" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING" maxRedeliveryCount="-1"/>
	  <queue id="sqinbd" maintainStrictOrder="true" maxMessageDepth="200000" failedDeliveryPolicy="KEEP_TRYING" maxRedeliveryCount="-1"/>
	  <queue id="cqinerrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="cqinbd" maxMessageDepth="100000" exceptionDestination="cqinerrbd"/>
	  <queue id="cqouterrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="cqoutbd" maxMessageDepth="100000" exceptionDestination="cqouterrbd"/>
	  <queue id="notferrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="notfbd" maxMessageDepth="100000" exceptionDestination="notferrbd"/>
  </messagingEngine>
</server>
' | base64 -w0)

SB3_B64=$(echo -n '<?xml version="1.0" encoding="UTF-8"?>
<server description="new server '${MAS_WORKSPACE_ID}'-manage-d--sb3--asc--sn">
<featureManager>
<feature>jndi-1.0</feature>
<feature>wasJmsClient-2.0</feature>
<feature>jmsMdb-3.2</feature>
<feature>mdb-3.2</feature>
</featureManager>
    <jmsQueueConnectionFactory jndiName="jms/maximo/int/cf/intcf" connectionManagerRef="mifjmsconfact"><properties.wasJms remoteServerAddress="'${MAS_INSTANCE_ID}'-'${MAS_WORKSPACE_ID}'-jms.mas-'${MAS_INSTANCE_ID}'-manage.svc:7276:BootstrapBasicMessaging"/></jmsQueueConnectionFactory>
    <connectionManager id="mifjmsconfact" maxPoolSize="20"/>
    <jmsQueue jndiName="jms/maximo/int/queues/sqout"><properties.wasJms queueName="sqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/sqin"><properties.wasJms queueName="sqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqin"><properties.wasJms queueName="cqinbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqinerr"><properties.wasJms queueName="cqinerrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqout"><properties.wasJms queueName="cqoutbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/cqouterr"><properties.wasJms queueName="cqouterrbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notf"><properties.wasJms queueName="notfbd"/></jmsQueue>
    <jmsQueue jndiName="jms/maximo/int/queues/notferr"><properties.wasJms queueName="notferrbd"/></jmsQueue>
    <jmsActivationSpec id="maximomea/mboejb/JMSContQueueProcessor-1" maxEndpoints="5"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqin" maxConcurrency="5" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContQueueProcessor-2" maxEndpoints="1"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqinerr" maxConcurrency="1" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContOutQueueProcessor-1" maxEndpoints="5"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqout" maxConcurrency="5" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
    <jmsActivationSpec id="maximomea/mboejb/JMSContOutQueueProcessor-2" maxEndpoints="1"><properties.wasJms destinationLookup="jms/maximo/int/queues/cqouterr" maxConcurrency="1" maxBatchSize="20" connectionFactoryLookup="jms/maximo/int/cf/intcf"/></jmsActivationSpec>
</server>
' | base64 -w0)

SB4_B64=$(echo -n '<?xml version="1.0" encoding="UTF-8"?>
<server description="new server '${MAS_WORKSPACE_ID}'-manage-d--sb4--asc--sn">

  <!-- Enable features -->
	<featureManager>
	  <feature>wasJmsSecurity-1.0</feature>
	  <feature>wasJmsServer-1.0</feature>
  </featureManager>
  <applicationManager autoExpand="true"/>
  <wasJmsEndpoint host="*" wasJmsSSLPort="7286" wasJmsPort="7276" />
  <messagingEngine>
	  <fileStore path="jms/jmsstore"/>
	  <queue id="sqoutbd" maintainStrictOrder="true" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING" maxRedeliveryCount="-1"/>
	  <queue id="sqinbd" maintainStrictOrder="true" maxMessageDepth="200000" failedDeliveryPolicy="KEEP_TRYING" maxRedeliveryCount="-1"/>
	  <queue id="cqinerrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="cqinbd" maxMessageDepth="100000" exceptionDestination="cqinerrbd"/>
	  <queue id="cqouterrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="cqoutbd" maxMessageDepth="100000" exceptionDestination="cqouterrbd"/>
	  <queue id="notferrbd" maxMessageDepth="100000" failedDeliveryPolicy="KEEP_TRYING"/>
	  <queue id="notfbd" maxMessageDepth="100000" exceptionDestination="notferrbd"/>
  </messagingEngine>
</server>
' | base64 -w0)

echo '
mas_app_server_bundles_combined_add_server_config:
  '${MAS_WORKSPACE_ID}'-manage-d--sb0--asc--sn: '${SB0_B64}'
  '${MAS_WORKSPACE_ID}'-manage-d--sb1--asc--sn: '${SB1_B64}'
  '${MAS_WORKSPACE_ID}'-manage-d--sb2--asc--sn: '${SB2_B64}'
  '${MAS_WORKSPACE_ID}'-manage-d--sb3--asc--sn: '${SB3_B64}'
  '${MAS_WORKSPACE_ID}'-manage-d--sb4--asc--sn: '${SB4_B64}'
' > $OUTPUT_FILE


echo "Server bundles generated: ${OUTPUT_FILE}"