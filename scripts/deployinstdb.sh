#!/bin/bash
# création du scropt de maj de la db de démo (décale les dates d'un jour à l'autre)

BACKUP_FTP="ncftpput -R -v -u $BC_ENV_FTP_DEV_USER -p $BC_ENV_FTP_DEV_PASS -P $BC_ENV_FTP_DEV_PORT $BC_ENV_FTP_DEV_HOST / install.sql.tar.gz"

mysqldump -hmysql -u root -p$SITE_DB_ROOT_PASSWORD $SITE_DB_NAME > install.sql
tar cvzf install.sql.tar.gz install.sql
if ${BACKUP_FTP} ;then
    echo "   FTP upload succeeded"
else
    echo "   FTP upload failed"
fi

rm install.sql install.sql.tar.gz
