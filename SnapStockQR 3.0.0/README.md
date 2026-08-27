# SnapStock QR 3.0.0

Aplicación Flutter Android para inventario corporativo con fotografías, consulta por
QR, roles, usuarios, exportación Excel e impresión de etiquetas por LPR/ZPL.

## Arquitectura

- API predeterminada: `https://api.jahmantencion.cl/api`.
- Autenticación: JWT emitido por SnapStock API.
- Rol `1`: consulta mediante QR.
- Rol `2`: administración completa del inventario.
- La sesión dura lo configurado por el servidor; al vencer, la app vuelve al login.
- Los deep links `fotocatalogo://registro/{uuid}` requieren una sesión válida.
- SQLite conserva una copia local de los registros creados/editados, pero el
  inventario oficial se carga desde la API.
- La configuración de impresora y etiqueta permanece al cerrar sesión.

La URL puede cambiarse al compilar sin editar el código:

```powershell
flutter build apk --release `
  --dart-define=SNAPSTOCK_API_URL=https://api.ejemplo.cl/api
```

El repositorio incluye dos sabores Android y scripts en la carpeta raíz:

```powershell
.\scripts\apk-local.ps1
.\scripts\apk-public.ps1
```

El sabor `local` usa `https://192.168.140.171/api` y confía en la CA privada de
esta instalación de Caddy. El sabor `public` usa
`https://api.jahmantencion.cl/api` y confía solamente en autoridades públicas del
sistema. Los identificadores de paquete son distintos, por lo que ambas APK se
pueden instalar simultáneamente durante las pruebas.

Para una entrega oficial, copie `android/key.properties.example` como
`android/key.properties` y configure una clave de firma que esté respaldada. Si no
existe, el proyecto compila deliberadamente un APK llamado `*_TEST_DEBUG_SIGNED.apk`;
ese archivo sirve para pruebas internas, no para distribución definitiva.

## Validación

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Orden de actualización

1. Detener la API anterior.
2. Publicar la API protegida y comprobar `/api/Registros/test`.
3. Instalar esta versión de la app.
4. Iniciar sesión. La API migrará automáticamente la contraseña antigua del usuario
   a PBKDF2 en su primer acceso correcto.

La app anterior no conoce los tokens y no debe utilizarse con la API protegida.
