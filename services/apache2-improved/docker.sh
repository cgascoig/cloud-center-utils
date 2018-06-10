#!/bin/bash

DOCKER_SVCNAME=apache2
DOCKER_SVCCONFIG_DIR="/etc/$DOCKER_SVCNAME"
DOCKER_VIRTUAL_HOST_CONFIG="$DOCKER_SVCCONFIG_DIR/sites-available/default-ssl"

. $OSSVC_HOME/utils/docker_util.sh
. $OSSVC_HOME/utils/nosqlutil.sh
. $OSSVC_HOME/utils/cfgutil.sh
. $OSSVC_HOME/utils/install_util.sh

DOCKER_IMAGE_NAME=`getDockerImageName $DOCKER_SVCNAME`

installDockerApache(){
    loadDockerImage $DOCKER_IMAGE_NAME
    dockerApachePostInstall
}

dockerApachePostInstall(){
    mkdir $DOCKER_SVCCONFIG_DIR

    echo "Adding directories sites-available and sites-enabled"
    mkdir $DOCKER_SVCCONFIG_DIR/sites-available $DOCKER_SVCCONFIG_DIR/sites-enabled
    cp $SVCHOME/etc/sites-available/* $DOCKER_SVCCONFIG_DIR/sites-available/
    replaceToken $DOCKER_SVCCONFIG_DIR/sites-available/default "%SVCNAME%" $DOCKER_SVCNAME
    replaceToken $DOCKER_SVCCONFIG_DIR/sites-available/default-ssl "%SVCNAME%" $DOCKER_SVCNAME

    #Since php:5.6-apache dockerfile use /var/www/html as the work dir, so need to change our app dir to match the docker image, otherwise, docker container can't start.
    replaceToken $DOCKER_SVCCONFIG_DIR/sites-available/default \/var\/www \/var\/www\/html
    replaceToken $DOCKER_SVCCONFIG_DIR/sites-available/default-ssl \/var\/www \/var\/www\/html

    chmod 0644 $DOCKER_SVCCONFIG_DIR/sites-available/*

    echo "adding ports.conf and ports.conf.ssl"
    mkdir $DOCKER_SVCCONFIG_DIR/portsconf
    cp $SVCHOME/etc/ports* $DOCKER_SVCCONFIG_DIR/portsconf
    chmod 0644 $DOCKER_SVCCONFIG_DIR/portsconf/*

    echo "Adding scripts a2ensite and a2dissite"
    cp $SVCHOME/etc/a2* /usr/sbin
    replaceToken /usr/sbin/a2ensite "httpd" $DOCKER_SVCNAME
    replaceToken /usr/sbin/a2dissite "httpd" $DOCKER_SVCNAME

    chmod +x /usr/sbin/a2*

    /usr/sbin/a2ensite default

    if [ $? -ne 0 ]; then
        log "Error while enabling default"
        exit $?
    fi
}

generateDockerApacheConfig(){
    source "$USER_ENV"
    if [ -z "$OSSVC_CONFIG" ]; then
        log "[CONFIGURATION] Waiting for the userenv to be available.."
        waitForPropertyInFile "$USER_ENV" "OSSVC_CONFIG"
        source "$USER_ENV"
    fi

    overrideNosqlIp
    deployDir=$BASE_DEPLOY_DIR/$cliqrWebappFolder
    BACKUP_DIR=$SVCHOME/bkp
    cd $deployDir

    CFG_LIST=(`echo $cliqrPhpAppConfigFiles | tr ";" "\n"`)
    for cfgFile in "${CFG_LIST[@]}"
    do
        log "[RESTORE-BACKUP] Restoring $BACKUP_DIR/$cfgFile "
        cp $BACKUP_DIR/$cfgFile $cfgFile
        replaceToken $cfgFile "%NOSQLDB_TIER_IP%" $CliqrTier_NoSQLDatabase_IP
        replaceToken $cfgFile "%DB_TIER_IP%" $CliqrTier_Database_IP
        replaceToken $cfgFile "%MB_TIER_IP%" $CliqrTier_MsgBus_IP
        replaceToken $cfgFile "%BC_TIER_IP%" $CliqrTier_BackendCache_IP
        replaceTierIpToken $cfgFile
    done

    log "[CONFIGURATION] Starting Apache configuration"
    apache_config

    if [ $? -ne 0 ]
    then
        log "[CONFIGURATION] Failed to configure $DOCKER_SVCNAME"
        exit 1
    else
        log "[CONFIGURATION] $DOCKER_SVCNAME configuration was successful"
    fi
}

apache_config(){

    cp $SVCHOME/conf/docker-apache2.conf $DOCKER_SVCCONFIG_DIR/apache2.conf

    #echo "Setting ports.conf as default"
    #uncommentConfig $DOCKER_SVCCONFIG_DIR/apache2.conf "#HTTP_ENABLED"

    if [ "$cliqrExternalHttpsEnabled" == 1 ]; then
        #echo "Setting ports.conf.ssh when https is enabled"
        #uncommentConfig $DOCKER_SVCCONFIG_DIR/apache2.conf "#HTTPS_ENABLED"
        if [ -n "$cliqrSSLCert" -a -n "$cliqrSSLKey" ]; then
            replaceToken $DOCKER_VIRTUAL_HOST_CONFIG "%SSL_CERT%" $cliqrSSLCert
            replaceToken $DOCKER_VIRTUAL_HOST_CONFIG "%SSL_KEY%" $cliqrSSLKey

        else
            replaceToken $DOCKER_VIRTUAL_HOST_CONFIG "%SSL_CERT%" "$DOCKER_SVCCONFIG_DIR/cert/vm.cliqr.com.crt"
            replaceToken $DOCKER_VIRTUAL_HOST_CONFIG "%SSL_KEY%" "$DOCKER_SVCCONFIG_DIR/cert//vm.cliqr.com.key"
        fi
        replaceToken $DOCKER_VIRTUAL_HOST_CONFIG "%SVCNAME%" $DOCKER_SVCNAME

        /usr/sbin/a2ensite default-ssl
        if [ $? -ne 0 ]; then
            log "Error while enabling ssl"
            exit 1
        else
            log "Successfully enabled ssl"
            /usr/sbin/a2dissite default
            echo "LoadModule ssl_module /usr/lib/apache2/modules/mod_ssl.so" >> $DOCKER_SVCCONFIG_DIR/apache2.conf
        fi
    fi
}

startDockerApacheService(){
    removeDockerContainer $DOCKER_SVCNAME
    docker run -d --name=$DOCKER_SVCNAME -v $DOCKER_SVCCONFIG_DIR/apache2.conf:$DOCKER_SVCCONFIG_DIR/apache2.conf \
                                         -v $BASE_DEPLOY_DIR:$BASE_DEPLOY_DIR/html \
                                         -v $DOCKER_SVCCONFIG_DIR/sites-available:$DOCKER_SVCCONFIG_DIR/sites-available \
                                         -v $DOCKER_SVCCONFIG_DIR/sites-enabled:$DOCKER_SVCCONFIG_DIR/sites-enabled   \
                                         -v /usr/local/osmosix/cert:$DOCKER_SVCCONFIG_DIR/cert \
                                         -p 80:80 -p 443:443 $DOCKER_IMAGE_NAME /bin/bash -c "docker-php-ext-install mysql; apache2-foreground" #add mysql extension before start
}

stopDockerApacheService(){
    docker stop $DOCKER_SVCNAME
    docker rm -f $DOCKER_SVCNAME
}

restartDockerApacheService(){
    stopDockerApacheService
    startDockerApacheService
}