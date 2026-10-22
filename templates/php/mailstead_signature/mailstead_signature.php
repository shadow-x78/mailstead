<?php
/**
 * mailstead_signature - apply server-rendered signatures in Roundcube.
 * Managed by Mailstead - do not edit.
 *
 * Reads ${APP_LIB}/signatures/rendered/<domain>/<local>.{html,txt} at login and
 * applies it to the standard identity according to the configured policy:
 *   default - set only when the identity signature is empty
 *   enforce - refresh whenever the rendered file is newer than the stored mtime
 *
 * [verify] Verify hook/identity API names against the installed Roundcube version.
 */
class mailstead_signature extends rcube_plugin
{
    public $task = '.*';

    /** @var rcmail */
    private $rc;

    public function init()
    {
        $this->rc = rcmail::get_instance();
        $this->load_config();
        $this->add_hook('login_after', [$this, 'on_login']);
    }

    public function on_login($args)
    {
        $rc   = $this->rc;
        $user = $rc->user;

        $email = method_exists($user, 'get_username') ? $user->get_username() : $rc->get_user_name();
        if (!$email || strpos($email, '@') === false) {
            return $args;
        }
        list($local, $domain) = explode('@', $email, 2);

        $base = $rc->config->get('mailstead_sig_dir', '/var/lib/mailstead/signatures/rendered');
        $file = rtrim($base, '/') . '/' . $domain . '/' . $local . '.html';
        if (!is_readable($file)) {
            return $args;
        }

        $html   = (string) @file_get_contents($file);
        $mtime  = (int) @filemtime($file);
        $policy = $rc->config->get('mailstead_sig_policy', 'default');
        $stored = (int) $rc->config->get('mailstead_sig_mtime', 0);

        $identities = $user->list_identities();
        foreach ($identities as $identity) {
            $id = isset($identity['identity_id']) ? $identity['identity_id'] : null;
            if ($id === null) {
                continue;
            }
            $is_default = !empty($identity['standard']) || !empty($identity['default']);
            if (!$is_default) {
                continue;
            }

            $existing = isset($identity['signature']) ? $identity['signature'] : '';
            if ($policy === 'enforce' && $mtime <= $stored && $existing !== '') {
                continue;
            }
            if ($policy !== 'enforce' && trim((string) $existing) !== '') {
                continue;
            }

            $user->update_identity($id, ['signature' => $html, 'html_signature' => 1]);
            $user->save_prefs(['mailstead_sig_mtime' => $mtime]);
            break;
        }

        return $args;
    }
}