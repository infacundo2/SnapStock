CREATE DATABASE IF NOT EXISTS snapstock
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE snapstock;

CREATE TABLE IF NOT EXISTS perfiles (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  nombre VARCHAR(100) NOT NULL,
  password VARCHAR(512) NOT NULL,
  tipo TINYINT UNSIGNED NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_perfiles_nombre (nombre),
  CONSTRAINT chk_perfiles_tipo CHECK (tipo IN (1, 2))
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS registros (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  uuid CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  nombre VARCHAR(200) NOT NULL,
  fecha VARCHAR(50) NOT NULL,
  observaciones VARCHAR(4000) NOT NULL DEFAULT '',
  categoria VARCHAR(100) NOT NULL,
  foto_paths MEDIUMTEXT NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_registros_uuid (uuid),
  KEY ix_registros_categoria (categoria)
) ENGINE=InnoDB;
