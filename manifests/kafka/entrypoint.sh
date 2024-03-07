#!/bin/bash

NODE_ID=$(echo $HOSTNAME|sed 's/[^0-9]*//g')
mkdir -p $SHARE_DIR/$NODE_ID

if [[ $PROCESS_ROLES == "broker" ]]; then

    LISTENERS="PLAINTEXT://:9092"
    NODE_ID=$((NODE_ID + 3))

    for i in $(seq 0 $(($CONTROLLER_REPLICAS - 1))); do
        CONTROLLER_QUORUM_VOTERS="$CONTROLLER_QUORUM_VOTERS$i@controller-$i.$CONTROLLER_SERVICE.$NAMESPACE.svc:9093,"
    done
    CONTROLLER_QUORUM_VOTERS=$(echo $CONTROLLER_QUORUM_VOTERS | sed 's/,$//')

    sed -e "s+^process.roles=.*+process.roles=$PROCESS_ROLES+" \
        -e "s+^node.id=.*+node.id=$NODE_ID+" \
        -e "s+^broker.id=.*+broker.id=$NODE_ID+" \
        -e "s+^listeners=.*+listeners=$LISTENERS+" \
        -e "s+^advertised.listeners=.*+advertised.listeners=$LISTENERS+" \
        -e "s+^log.dirs=.*+log.dirs=$SHARE_DIR/$NODE_ID+" \
        -e "s+^controller.quorum.voters=.*+controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS+" \
        -e "s+^num.partitions=.*+num.partitions=$KAFKA_NUM_PARTITIONS+" \
        -e "s+^controller.listeners.names=.*+controller.listeners.names=$CONTROLLER_LISTENER_NAMES+" \
        -e "s+^inter.broker.listener.name=.*+inter.broker.listener.name=$INTER_BROKER_LISTENER_NAME+" \
        -e "s+^listener.security.protocol.map=.*+listener.security.protocol.map=$CONTROLLER_LISTENER_SECURITY_PROTOCOL_MAP+" \
        /opt/kafka/config/kraft/broker.properties > /opt/kafka/broker.properties.updated \
        && mv /opt/kafka/broker.properties.updated /opt/kafka/config/kraft/broker.properties

    kafka-storage.sh format -t $CLUSTER_ID -c /opt/kafka/config/kraft/broker.properties
    exec kafka-server-start.sh /opt/kafka/config/kraft/broker.properties
fi

if [[ $PROCESS_ROLES =~ broker && $PROCESS_ROLES =~ controller ]]; then

    ADVERTISED_LISTENERS="PLAINTEXT://kafka-$NODE_ID.$SERVICE.$NAMESPACE.svc:9092"
    LISTENERS="PLAINTEXT://:9092,CONTROLLER://:9093"
    CONTROLLER_QUORUM_VOTERS=""

    for i in $(seq 0 $(($REPLICAS - 1))); do
        CONTROLLER_QUORUM_VOTERS="$CONTROLLER_QUORUM_VOTERS$i@kafka-$i.$SERVICE.$NAMESPACE.svc:9093,"
    done
    CONTROLLER_QUORUM_VOTERS=$(echo $CONTROLLER_QUORUM_VOTERS | sed 's/,$//')

    sed -e "s+^node.id=.*+node.id=$NODE_ID+" \
        -e "s+^num.partitions=.*+num.partitions=$KAFKA_NUM_PARTITIONS+" \
        -e "s+^controller.quorum.voters=.*+controller.quorum.voters=$CONTROLLER_QUORUM_VOTERS+" \
        -e "s+^listeners=.*+listeners=$LISTENERS+" \
        -e "s+^advertised.listeners=.*+advertised.listeners=$ADVERTISED_LISTENERS+" \
        -e "s+^log.dirs=.*+log.dirs=$SHARE_DIR/$NODE_ID+" \
        /opt/kafka/config/kraft/server.properties > /opt/kafka/server.properties.updated \
        && mv /opt/kafka/server.properties.updated /opt/kafka/config/kraft/server.properties

    echo "default.replication.factor=$DEFAULT_REPLICATION_FACTOR" >> /opt/kafka/config/kraft/server.properties
    echo "auto.create.topics.enable=$AUTO_CREATE_TOPICS_ENABLE" >> /opt/kafka/config/kraft/server.properties

    kafka-storage.sh format -t $CLUSTER_ID -c /opt/kafka/config/kraft/server.properties
    exec kafka-server-start.sh /opt/kafka/config/kraft/server.properties
fi

