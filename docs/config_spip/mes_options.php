<?php
define('_ID_WEBMASTERS','1');
	define('_LOGO_MAX_SIZE', 1000); # poids en ko
	define('_LOGO_MAX_WIDTH', 1920); # largeur en pixels
	define('_LOGO_MAX_HEIGHT', 1920); # hauteur en pixels
	define('_DOC_MAX_SIZE', 0); # poids en ko
	define('_IMG_MAX_SIZE', 1000); # poids en ko
	define('_IMG_MAX_WIDTH', 1920); # largeur en pixels
	define('_IMG_MAX_HEIGHT', 1920); # hauteur en pixels
	define('SPIP_ERREUR_REPORT',E_ALL);
//	define('SPIP_ERREUR_REPORT',E_ALL^E_NOTICE^E_STRICT);
	define('_AUTOBR', ''); # supprimer l'autobr de spip pour eviter la surcharge avec le <p> de ckeditor
// permet d'éviter l'affichage de la redirection 302 (ça ne devrait plus être utile à partir d'une certaine version à venir de spip)
	define('_SERVER_APACHE',true);
	date_default_timezone_set('TIME_ZONE');
// defini le https pour spip
	$_SERVER['SERVER_PORT']='443';
?>
