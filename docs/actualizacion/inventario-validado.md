# Inventario validado para publicación

Fecha de revisión: 21 de julio de 2026.

## Laravel

- URL: `https://liviase.sanmartin.edu.co`
- Framework: Laravel 12.64.0 después de aplicar actualizaciones compatibles de seguridad.
- PHP mínimo: 8.2.
- Pruebas: 65 aprobadas, 280 verificaciones.
- Auditoría Composer: sin avisos conocidos después de actualizar el lock.
- Estado del servidor antes de publicar:
  - `/up`: HTTP 200.
  - `/login`: HTTP 200.
  - `/api/contents`: HTTP 200.
  - `/api/microbusiness-fields`: HTTP 200.
  - `/api/content-categories`: HTTP 404; debe cambiar a 200 después del despliegue.

## Firebase

- Proyecto unificado: `liviase-af055`.
- Aplicación web: `1:448369198333:web:09b0bcb70241849c41ea94`.
- Aplicación Android: `1:448369198333:android:e260e592f2d0311f41ea94`.
- Google como proveedor de identidad: habilitado.
- Laravel necesita una credencial Firebase Admin del mismo proyecto.

## Android / Play Store

- `applicationId`: `co.edu.sanmartin.liviase`.
- Versión declarada actualmente: `1.0.2+3`.
- Firma de carga local: disponible mediante `android/key.properties` y el JKS configurado.
- Certificado de carga local comprobado:
  - SHA-1: `6F:48:09:0F:41:40:76:47:E1:31:22:DE:8D:94:06:AF:4A:F1:A8:F4`
  - SHA-256: `0B:EB:1F:15:46:08:A3:2C:EB:9D:34:83:99:A8:6E:85:A1:2B:59:6A:81:D8:A3:7B:F2:90:84:A1:1E:B0:6F:8F`

Compare esta huella con el **certificado de clave de carga** de Play Console. No la confunda con el certificado de firma administrado por Play.

## Bloqueos pendientes

1. Falta definir una `GOOGLE_MAPS_API_KEY` de producción restringida. El script del AAB se detiene deliberadamente mientras falte.
2. Debe consultarse en Play Console el mayor `versionCode` existente. El siguiente número tiene que ser superior.
3. El ZIP Laravel está generado, pero todavía no se ha subido al servidor público.
4. El AAB no se generó para evitar publicar una compilación con la clave de Maps de reemplazo.

## Artefacto administrativo generado

- Archivo: `dist/admin-web/liviase-admin-20260721.zip`
- SHA-256: `3237665BFEF92600F94B33E7D140F59316C05580B80BC18C1E9725D82F17716A`
- No contiene `.env`, logs, sesiones, imágenes de usuarios, credenciales Firebase, `vendor`, `node_modules` ni llaves de firma.
