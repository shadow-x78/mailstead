# milter_headers.conf - headers added for downstream sieve/Roundcube. Managed.
use = ["x-spam-flag", "x-spam-level", "authentication-results"];
authenticated_headers = ["authentication-results"];