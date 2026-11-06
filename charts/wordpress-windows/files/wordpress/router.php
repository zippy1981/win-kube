<?php
// Router for `php -S`: let the server handle real files and directories, send
// everything else (pretty permalinks) through WordPress's front controller.
$path = rawurldecode((string) parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH));
if ($path !== '' && file_exists($_SERVER['DOCUMENT_ROOT'] . $path)) {
    return false;
}
$_SERVER['SCRIPT_NAME'] = '/index.php';
require $_SERVER['DOCUMENT_ROOT'] . '/index.php';
