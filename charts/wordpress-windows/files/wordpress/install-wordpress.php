<?php
// Helm post-install/post-upgrade hook: drives the WordPress web installer once the
// site can reach MySQL. Idempotent — exits 0 when WordPress is already installed
// (for example after an upgrade, or when the emptyDir database survived).
$base = rtrim((string) getenv('WP_INTERNAL_URL'), '/');
$deadline = time() + (int) (getenv('WP_INSTALL_TIMEOUT') ?: 1800);

function request(string $url, ?array $form = null): array
{
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_CONNECTTIMEOUT => 10,
        CURLOPT_TIMEOUT => 300,
    ]);
    if ($form !== null) {
        curl_setopt($ch, CURLOPT_POST, true);
        curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query($form));
    }
    $body = curl_exec($ch);
    return [(int) curl_getinfo($ch, CURLINFO_RESPONSE_CODE), is_string($body) ? $body : '', curl_error($ch)];
}

function isInstalled(string $body): bool
{
    return stripos($body, 'Already Installed') !== false;
}

// install.php answers 500 ("Error establishing a database connection") until MySQL is up.
while (true) {
    [$code, $body, $error] = request("$base/wp-admin/install.php");
    if ($code === 200) {
        break;
    }
    if (time() >= $deadline) {
        fwrite(STDERR, "[win-kube] Timed out waiting for $base (last: HTTP $code $error)\n");
        exit(1);
    }
    echo "[win-kube] Waiting for WordPress and MySQL (HTTP $code $error)\n";
    sleep(10);
}

if (isInstalled($body)) {
    echo "[win-kube] WordPress is already installed\n";
    exit(0);
}

$password = (string) getenv('WP_ADMIN_PASSWORD');
echo "[win-kube] Installing WordPress as " . getenv('WP_ADMIN_USER') . "\n";
[$code, $body, $error] = request("$base/wp-admin/install.php?step=2", [
    'weblog_title' => getenv('WP_TITLE'),
    'user_name' => getenv('WP_ADMIN_USER'),
    'admin_password' => $password,
    'admin_password2' => $password,
    'pw_weak' => '1',
    'admin_email' => getenv('WP_ADMIN_EMAIL'),
    'blog_public' => '0',
    'language' => '',
    'Submit' => 'Install WordPress',
]);

[$verifyCode, $verifyBody] = request("$base/wp-admin/install.php");
if (isInstalled($verifyBody)) {
    echo "[win-kube] WordPress installed\n";
    exit(0);
}
fwrite(STDERR, "[win-kube] Install did not complete (HTTP $code $error)\n" . substr(strip_tags($body), 0, 2000) . "\n");
exit(1);
