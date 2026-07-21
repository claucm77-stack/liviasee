# Actualizar Livi@se en Google Play

Paquete inmutable: `co.edu.sanmartin.liviase`

## 1. Confirmar la versión actual

Abra Play Console y consulte **Prueba y lanzamiento > Últimos lanzamientos y paquetes**. Anote el mayor `versionCode` publicado o cargado en cualquier canal.

El proyecto declara actualmente `1.0.2+3`, pero el número real de Play Console es la autoridad. El nuevo `BuildNumber` debe ser mayor que todos los existentes.

Ejemplo si el mayor código es 3:

```powershell
$env:GOOGLE_MAPS_API_KEY = 'CLAVE_RESTRINGIDA_DE_PRODUCCION'
.\scripts\release\build-play-store.ps1 -BuildName '1.0.3' -BuildNumber 4
```

El script genera:

- `dist/play-store/liviase-1.0.3-4.aab`
- `dist/play-store/liviase-1.0.3-4.aab.sha256`

## 2. Clave Google Maps

La clave debe estar restringida en Google Cloud a:

- Aplicación Android `co.edu.sanmartin.liviase`.
- Huella SHA-1 del certificado que corresponda al APK instalado. En producción normalmente es el certificado de firma administrado por Play, no la clave local de carga.
- Solo las API de Maps realmente usadas.

El script se detiene si `GOOGLE_MAPS_API_KEY` no está definida, para impedir un AAB con la clave de reemplazo.

## 3. Firma

El proyecto usa la clave local de carga configurada en `android/key.properties`. Esta clave firma el AAB que se sube; Google Play vuelve a firmar los APK distribuidos cuando Play App Signing está activo.

No sustituya el `.jks` sin confirmar antes el certificado de carga en **Configuración > Integridad de la app**.

Puede verificar el AAB generado con:

```powershell
jarsigner -verify -verbose -certs .\dist\play-store\liviase-1.0.3-4.aab
```

## 4. Publicación segura

1. Entre a Play Console y seleccione Livi@se.
2. Abra **Prueba y lanzamiento > Pruebas internas**.
3. Cree una versión y cargue el `.aab`.
4. Revise errores de firma, `versionCode`, nivel de API, permisos y dispositivos excluidos.
5. Añada notas de versión, por ejemplo:

   ```text
   Mejoras en inicio de sesión, sincronización con el panel administrativo,
   imágenes, contenidos, micronegocios, docentes, foros y permisos por rol.
   ```

6. Publique primero en pruebas internas.
7. Instale la versión desde el enlace de Play y pruebe todos los roles contra `https://liviase.sanmartin.edu.co`.
8. Promueva la misma versión a producción mediante lanzamiento gradual.
9. Supervise fallos, ANR, comentarios y métricas antes de ampliar al 100 %.

## 5. Validaciones mínimas en el dispositivo

- Inicio con correo y con Google.
- Perfil y fotografía.
- Contenidos e imágenes.
- Directorio, creación, fotografía, calificación y favoritos de micronegocios.
- Botón **Cómo llegar**.
- Docentes y chat.
- Foros y respuestas del docente asignado.
- Dashboard y permisos de administrador/docente administrador.
- Cierre de sesión y bloqueo de cuentas inactivas.

Google exige conservar el mismo paquete y firma y aumentar el `versionCode` en cada actualización. Referencias oficiales:

- https://support.google.com/googleplay/android-developer/answer/9859350
- https://developer.android.com/studio/publish/upload-bundle
