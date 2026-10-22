#!/usr/bin/env bash
# phases/P11a_mta_sts.sh - MTA-STS policy for the primary domain.
PHASE_REQUIRES="mta-sts"

phase_P11a() {
    header "P11a mta-sts"
    mta_sts_add_domain "$PRIMARY_DOMAIN"
    log_info "MTA-STS configured (testing). Publish the _mta-sts TXT record."
}
