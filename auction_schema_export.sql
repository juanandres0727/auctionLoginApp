-- Full schema for BuyMe auction project
-- This will DROP and recreate auction_db

DROP SCHEMA IF EXISTS `auction_db`;
CREATE SCHEMA `auction_db`
  DEFAULT CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;
USE `auction_db`;

-- USERS (extends your original minimal table)
CREATE TABLE `users` (
  `user_id`       INT NOT NULL AUTO_INCREMENT,
  `username`      VARCHAR(50) NOT NULL UNIQUE,
  `password_hash` CHAR(64) NOT NULL,
  `email`         VARCHAR(100) NULL,
  `role`          ENUM('END_USER','REP','ADMIN') NOT NULL DEFAULT 'END_USER',
  `active`        TINYINT(1) NOT NULL DEFAULT 1,
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `uk_users_username` (`username`)
) ENGINE=InnoDB;

-- Seed user from your original script
INSERT INTO `users` (`username`, `password_hash`)
VALUES ('demo_user', 'db9f57e3dab2c039c93c6c0c7687f1f6b32d24f00c4d527f406e67a5145e8e3c');

-- CATEGORIES (3-level hierarchy)
CREATE TABLE `categories` (
  `category_id`        INT NOT NULL AUTO_INCREMENT,
  `name`               VARCHAR(100) NOT NULL,
  `parent_category_id` INT NULL,
  PRIMARY KEY (`category_id`),
  CONSTRAINT `fk_cat_parent`
    FOREIGN KEY (`parent_category_id`)
    REFERENCES `categories` (`category_id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

-- Example seed categories (you can change later)
INSERT INTO categories (name, parent_category_id) VALUES
('Electronics', NULL),
--('Clothing',    NULL),
('Home',        NULL);

INSERT INTO categories (name, parent_category_id) VALUES
('Phones',   1),
('Laptops',  1),
('Men',      2),
('Women',    2);

INSERT INTO categories (name, parent_category_id) VALUES
('iPhone',   4),
('Android',  4);

-- AUCTIONS
CREATE TABLE `auctions` (
  `auction_id`    INT NOT NULL AUTO_INCREMENT,
  `seller_id`     INT NOT NULL,
  `title`         VARCHAR(200) NOT NULL,
  `description`   TEXT,
  `category_id`   INT NOT NULL,
  `start_price`   DECIMAL(10,2) NOT NULL,
  `min_increment` DECIMAL(10,2) NOT NULL,
  `reserve_price` DECIMAL(10,2) NOT NULL,
  `start_time`    DATETIME NOT NULL,
  `end_time`      DATETIME NOT NULL,
  `current_price` DECIMAL(10,2) NOT NULL,
  `status`        ENUM('OPEN','CLOSED','CANCELLED') NOT NULL DEFAULT 'OPEN',
  `created_at`    TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`auction_id`),
  CONSTRAINT `fk_auc_seller`
    FOREIGN KEY (`seller_id`) REFERENCES `users`(`user_id`),
  CONSTRAINT `fk_auc_cat`
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`category_id`)
) ENGINE=InnoDB;

-- BIDS
CREATE TABLE `bids` (
  `bid_id`     INT NOT NULL AUTO_INCREMENT,
  `auction_id` INT NOT NULL,
  `bidder_id`  INT NOT NULL,
  `bid_amount` DECIMAL(10,2) NOT NULL,
  `bid_time`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`bid_id`),
  CONSTRAINT `fk_bid_auc`
    FOREIGN KEY (`auction_id`) REFERENCES `auctions`(`auction_id`),
  CONSTRAINT `fk_bid_user`
    FOREIGN KEY (`bidder_id`) REFERENCES `users`(`user_id`)
) ENGINE=InnoDB;

-- AUTO BIDS
CREATE TABLE `auto_bids` (
  `auto_bid_id` INT NOT NULL AUTO_INCREMENT,
  `auction_id`  INT NOT NULL,
  `bidder_id`   INT NOT NULL,
  `max_amount`  DECIMAL(10,2) NOT NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`auto_bid_id`),
  UNIQUE KEY `uk_auto_auc_user` (`auction_id`, `bidder_id`),
  CONSTRAINT `fk_auto_auc`
    FOREIGN KEY (`auction_id`) REFERENCES `auctions`(`auction_id`),
  CONSTRAINT `fk_auto_user`
    FOREIGN KEY (`bidder_id`) REFERENCES `users`(`user_id`)
) ENGINE=InnoDB;

-- ALERTS
CREATE TABLE `alerts` (
  `alert_id`    INT NOT NULL AUTO_INCREMENT,
  `user_id`     INT NOT NULL,
  `category_id` INT NULL,
  `keyword`     VARCHAR(100) NULL,
  `min_price`   DECIMAL(10,2) NULL,
  `max_price`   DECIMAL(10,2) NULL,
  `created_at`  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`alert_id`),
  CONSTRAINT `fk_alert_user`
    FOREIGN KEY (`user_id`) REFERENCES `users`(`user_id`),
  CONSTRAINT `fk_alert_cat`
    FOREIGN KEY (`category_id`) REFERENCES `categories`(`category_id`)
) ENGINE=InnoDB;