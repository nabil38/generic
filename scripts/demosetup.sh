#!/bin/bash
# création du scropt de maj de la db de démo (décale les dates d'un jour à l'autre)
cat <<EOFF >> /shiftdb.sh
#!/bin/bash
if [ -z \$1 ] ; then DAYS=1 ; else DAYS=\$1 ; fi

mysql -hmysql -u root -p$SITE_DB_ROOT_PASSWORD $SITE_DB_NAME <<EOF
update spip_evenements set date_debut=DATE_ADD(date_debut, INTERVAL \$DAYS DAY),date_fin=DATE_ADD(date_fin, INTERVAL \$DAYS DAY);
update commande set date=DATE_ADD(date, INTERVAL \$DAYS DAY),datefact=DATE_ADD(datefact, INTERVAL \$DAYS DAY);
update spip_mouvements set date_mvt=DATE_ADD(date_mvt, INTERVAL \$DAYS DAY) where mouvement!='origine';
update spip_paiements set date=DATE_ADD(date, INTERVAL \$DAYS DAY);
update spip_paiements set date_validation=DATE_ADD(date_validation, INTERVAL $DAYS DAY) where date_validation!='0000-00-00';
update spip_paiements set date_encaissement=DATE_ADD(date_encaissement, INTERVAL $DAYS DAY) where date_encaissement!='0000-00-00';
update spip_paiements set date_annulation=DATE_ADD(date_annulation, INTERVAL $DAYS DAY) where date_annulation!='0000-00-00';
update spip_remises set date=DATE_ADD(date, INTERVAL \$DAYS DAY);
update spip_soins set date_soin=DATE_ADD(date_soin, INTERVAL \$DAYS DAY);
EOF
EOFF
chmod +x /shiftdb.sh
# programation du script pour exécution journalière
ln -s /shiftdb.sh /etc/periodic/daily/shiftdb
# annulation du décalage pour le Lundi et le vendredi pour éviter d'avoir un phénomene de stacking des commandes
sed -i "\$i 0       2       *       *       1,5     ./shiftdb.sh -1" /etc/crontabs/root
# demarage de crond si pas déjà démarré
if [ $(ps -ef | grep -v grep | grep crond | wc -l) -eq 0 ]; then crond; fi
