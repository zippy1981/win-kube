<?php
// Installed by the wordpress-windows chart. Every setting comes from the pod environment.
define('DB_NAME', getenv('WORDPRESS_DB_NAME'));
define('DB_USER', getenv('WORDPRESS_DB_USER'));
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD'));
define('DB_HOST', getenv('WORDPRESS_DB_HOST'));
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

foreach (['AUTH_KEY', 'SECURE_AUTH_KEY', 'LOGGED_IN_KEY', 'NONCE_KEY',
          'AUTH_SALT', 'SECURE_AUTH_SALT', 'LOGGED_IN_SALT', 'NONCE_SALT'] as $key) {
    define($key, getenv("WORDPRESS_$key"));
}

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

define('WP_DEBUG', filter_var(getenv('WORDPRESS_DEBUG'), FILTER_VALIDATE_BOOLEAN));

// Follow whichever host the client used (NodePort, port-forward, service DNS) so the
// site works without knowing the node IP at install time.
if (!empty($_SERVER['HTTP_HOST'])) {
    define('WP_HOME', 'http://' . $_SERVER['HTTP_HOST']);
    define('WP_SITEURL', WP_HOME);
}

// php -S is single-threaded on Windows; WP-Cron loopback requests would stall it.
define('DISABLE_WP_CRON', true);
define('FS_METHOD', 'direct');

if (!defined('ABSPATH')) {
    define('ABSPATH', __DIR__ . '/');
}
require_once ABSPATH . 'wp-settings.php';
