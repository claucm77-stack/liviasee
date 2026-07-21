# Actualización de Livi@se

Este directorio contiene el procedimiento reproducible para publicar los dos componentes de Livi@se:

- Panel administrativo y API Laravel: `https://liviase.sanmartin.edu.co`
- Aplicación Android: Google Play, paquete `co.edu.sanmartin.liviase`

## Orden recomendado

1. Leer [actualizar-admin-web.md](actualizar-admin-web.md).
2. Publicar primero Laravel y comprobar `/up`, `/login` y la API.
3. Leer [actualizar-play-store.md](actualizar-play-store.md).
4. Generar el AAB apuntando a la URL productiva.
5. Subir el AAB a pruebas internas, probarlo y después promoverlo a producción.
6. Completar [checklist-publicacion.md](checklist-publicacion.md).

Consulte también [inventario-validado.md](inventario-validado.md) para ver los datos técnicos comprobados en este equipo y los bloqueos pendientes.

## Archivos preparados

| Archivo | Finalidad |
|---|---|
| `deployment/.env.production.example` | Plantilla segura del entorno Laravel productivo. |
| `scripts/release/build-admin-package.ps1` | Ejecuta pruebas, compila Vite y crea un ZIP del panel. |
| `scripts/release/build-play-store.ps1` | Valida firma, versión y clave de Maps; genera AAB y SHA-256. |
| `scripts/release/verify-production.ps1` | Comprueba salud, login y endpoints públicos después del despliegue. |


## Datos que nunca deben subirse a Git

- `.env` de producción.
- Credenciales JSON de Firebase Admin.
- `android/key.properties`.
- Archivos `.jks` o contraseñas de firma.
- Claves API sin restricciones.

Las credenciales Firebase de Laravel y la aplicación cliente deben pertenecer al mismo proyecto: `liviase-af055`.
