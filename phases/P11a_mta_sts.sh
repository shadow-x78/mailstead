#!/usr/bin/env bash
PHASE_REQUIRES="mta-sts"

phase_P11a() {
    header "P11a mta-sts"
    mta_sts_add_domain "$PRIMARY_DOMAIN"
    log_info "MTA-STS configured (testing). Publish the _mta-sts TXT record."
}
