-- ─────────────────────────────────────────────
-- Mailstead - Database Schema
-- https://github.com/shadow-x78/mailstead
-- ─────────────────────────────────────────────

-- Applied with: mysql mailserver < this file. All statements are idempotent.

CREATE TABLE IF NOT EXISTS domain (
    domain      VARCHAR(255) NOT NULL,
    description VARCHAR(255) NOT NULL DEFAULT '',
    aliases     INT          NOT NULL DEFAULT 0,
    mailboxes   INT          NOT NULL DEFAULT 0,
    maxquota    BIGINT       NOT NULL DEFAULT 0,
    quota       BIGINT       NOT NULL DEFAULT 0,
    transport   VARCHAR(255) NOT NULL DEFAULT 'virtual',
    backupmx    TINYINT(1)   NOT NULL DEFAULT 0,
    created     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active      TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS mailbox (
    username   VARCHAR(255) NOT NULL,
    password   VARCHAR(255) NOT NULL,
    name       VARCHAR(255) NOT NULL DEFAULT '',
    maildir    VARCHAR(255) NOT NULL DEFAULT '',
    quota      BIGINT       NOT NULL DEFAULT 0,
    local_part VARCHAR(255) NOT NULL DEFAULT '',
    domain     VARCHAR(255) NOT NULL,
    created    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active     TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (username),
    KEY idx_domain (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS alias (
    address  VARCHAR(255) NOT NULL,
    goto     TEXT         NOT NULL,
    domain   VARCHAR(255) NOT NULL,
    created  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active   TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (address),
    KEY idx_domain (domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE IF NOT EXISTS alias_domain (
    alias_domain  VARCHAR(255) NOT NULL,
    target_domain VARCHAR(255) NOT NULL,
    created       DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    modified      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    active        TINYINT(1)   NOT NULL DEFAULT 1,
    PRIMARY KEY (alias_domain)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;
