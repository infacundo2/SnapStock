# Estado de SnapStock

Fecha de revisión: 27 de agosto de 2026.

## Estado local

- MySQL: servicio `SnapStockMySQL`, datos en `C:\ProgramData\SnapStockMySQL\data`.
- API: servicio `SnapStockApi`, origen privado `http://127.0.0.1:5000`.
- HTTPS local: servicio `Caddy`, URL `https://192.168.140.171`.
- Fotografías: `C:\ProgramData\SnapStockApi\fotos`.
- Modo activo: local.
- `GET /api/Registros/test` comprobado correctamente.

Los servicios MySQL, API y Caddy tienen inicio automático y recuperación ante fallos.

## Cambio de entorno

La configuración común está en `snapstock-mode.json`. `UseLocal` indica el entorno
activo y las URLs se mantienen separadas de las credenciales.

Abra PowerShell como administrador en la raíz y ejecute uno de estos accesos:

```powershell
.\api local.ps1
.\api publica.ps1
.\apk local.ps1
.\apk publica.ps1
```

Los scripts equivalentes con nombres sin espacios viven en `scripts`.

- `api local.ps1` activa local, inicia MySQL/API/Caddy y detiene el túnel si existe.
- `api publica.ps1` activa pública, inicia MySQL/API y el servicio `cloudflared`.
- `apk local.ps1` genera una APK para `https://192.168.140.171/api`.
- `apk publica.ps1` genera una APK para `https://api.jahmantencion.cl/api`.

## APK comprobadas

- `SnapStockQR 3.0.0\build\app\outputs\flutter-apk\app-local-release.apk`
- `SnapStockQR 3.0.0\build\app\outputs\flutter-apk\app-public-release.apk`

El flavor local usa el paquete `com.example.foto_catalogo.local`, se muestra como
`SnapStock QR Local` y confía en la CA privada de esta instalación de Caddy. El
flavor público mantiene `com.example.foto_catalogo` y sólo confía en autoridades
públicas del sistema. Ambos se pueden instalar simultáneamente.

`flutter analyze` y `flutter test` terminan correctamente. Las APK fueron compiladas
en release para ARM, ARM64 y x86_64. Para distribución oficial todavía se recomienda
configurar y respaldar una clave Android propia.

## Cloudflare Tunnel

`api.jahmantencion.cl` ya es una aplicación publicada del túnel existente. No se
debe cambiar por un registro A hacia `152.230.114.194` mientras se conserve el
túnel. En Cloudflare, el servicio de origen de esa ruta debe ser
`http://127.0.0.1:5000`.

El ejecutable `cloudflared` está instalado, pero el túnel sigue sin registrarse en
esta VM porque falta el token completo. Para agregar esta máquina como réplica:

```powershell
$token = Read-Host 'Token del túnel de Cloudflare' -AsSecureString
.\api publica.ps1 -TunnelToken $token
```

El token es un secreto: no debe guardarse en el repositorio ni pegarse en capturas.
Una vez registrado, Cloudflare inicia el conector como servicio de Windows y no es
necesario abrir ni redirigir el puerto 443 público hacia esta VM.
