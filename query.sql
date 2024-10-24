-- Prueba técnica CEFAFA
-- Creado por: Josué Rauda
-- NOTA: Si los procedimientos almacenados no se crean al ejecutar completamente el archivo, ejecutar el código aparte

USE mysql;

DROP DATABASE if EXISTS cefafa_prueba_tecnica_josuerauda;
CREATE DATABASE cefafa_prueba_tecnica_josuerauda;

USE cefafa_prueba_tecnica_josuerauda;

CREATE TABLE tipo_usuario (
	idtipousuario INT(32) NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'ID de tipo de usuario',
	nombre VARCHAR(255) NOT NULL COMMENT 'Nombre de tipo de usuario',
	activo ENUM('SI','NO') DEFAULT 'SI' NOT NULL COMMENT 'Registro activo',
	fecha_creacion DATETIME DEFAULT NOW() NOT NULL COMMENT 'Fecha de creacion de registro',
	eliminado ENUM('SI','NO') DEFAULT 'NO' NOT NULL COMMENT 'Registro eliminado'
) COMMENT 'Tipos de Usuarios';

CREATE TABLE usuarios (
	idusuario INT(32) NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'ID de usuario',
	usuario VARCHAR(100) NOT NULL COMMENT 'Nombre de usuario. Ejemplo: jrauda',
	idtipousuario INT(32) NOT NULL COMMENT 'Tipo de usuario',
	numintentospassword INT(32) DEFAULT 0 COMMENT 'Número de intentos de contraseña fallida',
	bloqueado ENUM('SI','NO') DEFAULT 'NO' COMMENT 'Usuario bloqueado',
	nombre1 VARCHAR(100) NOT NULL COMMENT 'Primer nombre',
	nombre2 VARCHAR(100) COMMENT 'Segundo nombre',
	nombre3 VARCHAR(100) COMMENT 'Tercer nombre',
	nombre4 VARCHAR(100) COMMENT 'Cuarto nombre',
	apellido1 VARCHAR(100) NOT NULL COMMENT 'Primer apellido',
	apellido2 VARCHAR(100) COMMENT 'Segundo apellido',
	email VARCHAR(255) NOT NULL COMMENT 'Email',
	tel_casa_sv VARCHAR(9) COMMENT 'Teléfono de casa. Se guarda con guión',
	tel_cel_sv VARCHAR(9) COMMENT 'Teléfono celular. Se guarda con guión',
	tel_cel_alternativo VARCHAR(30) COMMENT 'Telefono alternativo. Para internacional, ejemplo: "(503) 456-7890". 30 carácteres según factura electrónica',
	activo ENUM('SI','NO') DEFAULT 'SI' NOT NULL COMMENT 'Registro activo',
	idregusuario INT(32) COMMENT 'Registrado por',
	fecha_creacion DATETIME DEFAULT NOW() NOT NULL COMMENT 'Fecha de creacion de registro',
	eliminado ENUM('SI','NO') DEFAULT 'NO' NOT NULL COMMENT 'Registro eliminado',
	CONSTRAINT fk_usuarios_usuarios FOREIGN KEY (idregusuario) REFERENCES usuarios (idusuario),
	CONSTRAINT fk_usuarios_tipo_usuario FOREIGN KEY (idtipousuario) REFERENCES tipo_usuario (idtipousuario)
) COMMENT 'Usuarios';

ALTER TABLE tipo_usuario
ADD idregusuario INT(32) COMMENT 'Registrado por' AFTER activo;
ALTER TABLE tipo_usuario
ADD CONSTRAINT fk_usuario_tipo FOREIGN KEY (idregusuario) REFERENCES usuarios (idusuario);

CREATE TABLE usuario_password (
	idusuariopassword INT(32) NOT NULL PRIMARY KEY AUTO_INCREMENT,
	idusuario INT(32) NOT NULL,
	pwd VARBINARY(255) NOT NULL,
	fecha_vencimiento DATE,
	activo ENUM('SI','NO') DEFAULT 'SI' NOT NULL COMMENT 'Registro activo',
	fecha_creacion DATETIME DEFAULT NOW() NOT NULL COMMENT 'Fecha de creacion de registro',
	eliminado ENUM('SI','NO') DEFAULT 'NO' NOT NULL COMMENT 'Registro eliminado',
	CONSTRAINT fk_usuarios_password FOREIGN KEY (idusuario) REFERENCES usuarios (idusuario)
);

CREATE TABLE categorias (
	idcategoria INT(32) NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'ID de categoria',
	nombre VARCHAR(255) NOT NULL COMMENT 'Nombre de categoria',
	activo ENUM('SI','NO') DEFAULT 'SI' NOT NULL COMMENT 'Registro activo',
	idregusuario INT(32) NOT NULL COMMENT 'Registrado por',
	fecha_creacion DATETIME DEFAULT NOW() NOT NULL COMMENT 'Fecha de creacion de registro',
	eliminado ENUM('SI','NO') DEFAULT 'NO' NOT NULL COMMENT 'Registro eliminado',
	CONSTRAINT fk_usuarios_categoria FOREIGN KEY (idregusuario) REFERENCES usuarios (idusuario)
) COMMENT 'Categorias';

CREATE TABLE productos (
	idproducto INT(32) NOT NULL PRIMARY KEY AUTO_INCREMENT COMMENT 'ID de producto',
	codigo VARCHAR(36) NOT NULL COMMENT 'Codigo UUIDv4',
	nombre VARCHAR(255) NOT NULL COMMENT 'Nombre de producto',
	descripcion LONGTEXT NOT NULL COMMENT 'Descripción del producto',
	stock INT(32) NOT NULL DEFAULT 0 COMMENT 'Numero de existencias',
	precio_unitario DECIMAL(16,2) DEFAULT 0.00 COMMENT 'Precio unitario de producto',
	activo ENUM('SI','NO') DEFAULT 'SI' NOT NULL COMMENT 'Registro activo',
	idregusuario INT(32) NOT NULL COMMENT 'Registrado por',
	fecha_creacion DATETIME DEFAULT NOW() NOT NULL COMMENT 'Fecha de creacion de registro',
	eliminado ENUM('SI','NO') DEFAULT 'NO' NOT NULL COMMENT 'Registro eliminado',
	CONSTRAINT fk_usuarios_productos FOREIGN KEY (idregusuario) REFERENCES usuarios (idusuario)
) COMMENT 'Productos';

-- Obtener nombre de usuario
DELIMITER //
DROP FUNCTION IF EXISTS GetNombreUsuario;
CREATE FUNCTION GetNombreUsuario (idusuario INT(32))
DETERMINISTIC
RETURNS VARCHAR(255)
BEGIN
	RETURN (
		SELECT
			CONCAT(
				b.nombre1,
				IFNULL(CONCAT(' ', b.nombre2),''),
				IFNULL(CONCAT(' ', b.nombre3),''),
				IFNULL(CONCAT(' ', b.nombre4),''),
				IFNULL(CONCAT(' ', b.apellido1),''),
				IFNULL(CONCAT(' ', b.apellido2),'')
			)
		FROM usuarios a
		WHERE a.idusuario=idusuario
	);
END;
//

-- Creación de password encriptado
DELIMITER //
DROP PROCEDURE IF EXISTS CreatePwd;
CREATE PROCEDURE CreatePwd (IN iduser INT(32),IN pwd VARCHAR(255))
BEGIN
	DECLARE newPwd VARBINARY(255);
	DECLARE fechaVencimiento DATE;
	
	SET newPwd = AES_ENCRYPT(pwd,'Unicornio Volador');
	SET fechaVencimiento = DATE_ADD(CURDATE(),INTERVAL 3 MONTH);
	
	UPDATE usuario_password SET activo='NO' WHERE idusuario=iduser;
	INSERT INTO usuario_password VALUES (NULL, iduser, newPwd, fechaVencimiento, 'SI', NOW(), 'NO');
END;
//

-- Validar usuario y contraseña
DELIMITER //
DROP PROCEDURE IF EXISTS ValidarPwd;
CREATE PROCEDURE ValidarPwd (IN idusuario VARCHAR(100), IN pwdAValidar VARCHAR(255))
BEGIN
	DECLARE pwdAValidarEncriptado VARBINARY(255);
	DECLARE pwdOriginal VARBINARY(255);
	DECLARE esPwdCorrecto ENUM('SI','NO','BK');
	DECLARE esUsuarioBloqueado ENUM('SI','NO');

	SET pwdAValidarEncriptado = AES_ENCRYPT(pwdAValidar,'Unicornio Volador');
	SET pwdOriginal = (SELECT a.pwd FROM usuario_password a WHERE a.idusuario=idusuario AND a.fecha_vencimiento>=CURDATE() AND a.activo='SI' AND a.eliminado='NO' ORDER BY a.fecha_creacion DESC LIMIT 1);
	SET esUsuarioBloqueado = (SELECT b.bloqueado FROM usuarios b WHERE b.idusuario=idusuario);

	SET esPwdCorrecto = (SELECT IF(pwdAValidarEncriptado = pwdOriginal, 'SI', 'NO'));
	
	IF(esUsuarioBloqueado = 'NO') THEN
		IF (esPwdCorrecto = 'NO') THEN
			UPDATE usuarios A1 SET
				A1.numintentospassword=(SELECT (A2.numintentospassword + 1) FROM usuarios A2 WHERE A2.idusuario=idusuario)
			WHERE A1.idusuario=idusuario;
		ELSE
			UPDATE usuarios B1 SET
				B1.numintentospassword=0
			WHERE B1.idusuario=idusuario;
		END IF;
		
		IF ((SELECT IF(C3.numintentospassword>=3,'SI','NO') FROM usuarios C3 WHERE C3.idusuario=idusuario)='SI') THEN
			SET esPwdCorrecto = 'BK';
			UPDATE usuarios SET bloqueado='SI' WHERE idusuario=idusuario;
		END IF;
	ELSE
		SET esPwdCorrecto = 'BK';
	END IF;
	
	SELECT esPwdCorrecto;
END;
//