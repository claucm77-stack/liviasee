# Checklist de publicación

Versión: ____________________  Fecha: ____________________  Responsable: ____________________

## Antes de Laravel

- [ ] Código revisado y pruebas Laravel aprobadas.
- [ ] Pruebas Flutter y análisis estático aprobados.
- [ ] Respaldo MySQL verificado.
- [ ] Respaldo de `storage/app` verificado.
- [ ] `.env` productivo respaldado.
- [ ] Credencial Firebase corresponde a `liviase-af055`.

## Después de Laravel

- [ ] `https://liviase.sanmartin.edu.co/up` responde 200.
- [ ] Login web funciona.
- [ ] Migraciones terminaron sin error.
- [ ] Imágenes existentes continúan visibles.
- [ ] API pública devuelve datos reales.
- [ ] Logs no contienen errores nuevos.

## Antes de Play Store

- [ ] `BuildNumber` es mayor que el máximo de Play Console.
- [ ] URL Laravel del AAB es HTTPS productiva.
- [ ] Clave Google Maps restringida y configurada.
- [ ] AAB firmado con la clave de carga correcta.
- [ ] SHA-256 del AAB guardado.
- [ ] Notas de versión preparadas.

## Pruebas internas

- [ ] Instalación desde Google Play completada.
- [ ] Inicio con correo funciona.
- [ ] Inicio con Google funciona.
- [ ] Matriz de roles verificada.
- [ ] Datos web/app visibles en ambos lados.
- [ ] Fotografías y archivos visibles.
- [ ] Chats, foros y calificaciones funcionan.

## Producción

- [ ] Lanzamiento gradual iniciado.
- [ ] Crash/ANR revisados.
- [ ] Logs Laravel revisados.
- [ ] Lanzamiento ampliado al 100 %.
- [ ] Artefactos, hash y respaldos archivados.
