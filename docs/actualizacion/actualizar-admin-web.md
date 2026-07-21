# Actualizar el panel administrativo Laravel

Destino: `https://liviase.sanmartin.edu.co/login`

## 1. Requisitos del servidor

- PHP 8.2 o superior y extensiones requeridas por Laravel.
- MySQL con respaldo disponible.
- Composer 2.
- El dominio debe apuntar al directorio `public/`, nunca a la raíz del proyecto.
- `storage/` y `bootstrap/cache/` deben ser escribibles por el usuario del servidor web.
- HTTPS activo.

## 2. Preparar el paquete en Windows

Desde PowerShell, en la raíz del proyecto:

```powershell
.\scripts\release\build-admin-package.ps1
```

El resultado queda en `dist/admin-web/`. El ZIP no contiene `.env`, credenciales Firebase, dependencias locales ni llaves privadas.

## 3. Respaldo obligatorio en producción

Antes de reemplazar archivos:

```bash
cd /ruta/de/liviase
php artisan down --retry=60
mysqldump --single-transaction -u USUARIO -p BASE_DATOS > ../backup-liviase-$(date +%Y%m%d-%H%M).sql
tar -czf ../backup-storage-$(date +%Y%m%d-%H%M).tar.gz storage/app
cp .env ../env-liviase-$(date +%Y%m%d-%H%M).backup
```

No continúe si el respaldo de base de datos queda vacío o termina con error.

## 4. Variables de producción

Use `deployment/.env.production.example` como referencia. Mantenga el `APP_KEY` actual: cambiarlo invalida datos cifrados y sesiones.

Puntos críticos:

- `APP_URL=https://liviase.sanmartin.edu.co`
- `APP_DEBUG=false`
- `SESSION_SECURE_COOKIE=true`
- `FIREBASE_CREDENTIALS` debe apuntar al JSON privado del proyecto `liviase-af055` fuera del directorio público.
- Las credenciales MySQL deben ser las reales del servidor.

## 5. Instalar la nueva versión

Descomprima el paquete en una carpeta de versión o copie sus archivos sobre el proyecto conservando `.env`, `storage/app` y las credenciales privadas.

```bash
cd /ruta/de/liviase
composer install --no-dev --prefer-dist --optimize-autoloader --no-interaction
php artisan optimize:clear
php artisan migrate --force
php artisan storage:link
php artisan optimize
php artisan reload
php artisan up
```

Si el servidor no usa procesos de cola, `php artisan reload` puede no reiniciar nada y es seguro. Si usa Supervisor, compruebe además que los workers vuelvan a estar activos.

## 6. Verificación

Desde el equipo local:

```powershell
.\scripts\release\verify-production.ps1
```

Compruebe manualmente:

1. Inicio de sesión del administrador.
2. Dashboard, usuarios, categorías, contenidos, micronegocios, foros y logs.
3. Carga y visualización de imágenes.
4. Creación de un registro de prueba controlado y su visibilidad en la app.
5. Inicio con Google desde la app.

## 7. Reversión

Si falla una verificación:

1. Ejecute `php artisan down`.
2. Restaure el código anterior.
3. Restaure `.env` y `storage/app` si fueron alterados.
4. Restaure la base de datos solo si una migración incompatible ya modificó datos.
5. Ejecute `composer install --no-dev`, `php artisan optimize` y `php artisan up`.

No use `migrate:rollback` a ciegas en producción: primero revise la migración y el respaldo.

Referencia oficial: https://laravel.com/docs/12.x/deployment
