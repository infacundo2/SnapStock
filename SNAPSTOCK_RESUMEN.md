# Estado de SnapStock

Fecha de revisión: 17 de agosto de 2026.

## Componentes

### SnapStock QR 3.0.0

Aplicación Flutter Android ubicada en `SnapStockQR 3.0.0`.

Funciones conservadas:

- Login corporativo.
- Roles de consulta (`tipo = 1`) y administración (`tipo = 2`).
- Inventario con fotografías y categorías.
- Consulta mediante QR y deep links.
- Gestión de usuarios.
- Exportación a Excel.
- Impresión de etiquetas QR mediante LPR/ZPL.

La app usa JWT, guarda el token en el almacén cifrado de Android y ya no accede a
Supabase. La API se puede cambiar con `SNAPSTOCK_API_URL` al compilar.

### SnapStock API

API ASP.NET Core 8 ubicada en `SnapStockApi`.

- Autenticación JWT y autorización por roles.
- Contraseñas nuevas con PBKDF2.
- Migración de contraseñas antiguas al primer login correcto.
- Límite de intentos de login.
- Validación de cantidad, tamaño, tipo y firma de imágenes.
- Errores internos registrados en el servidor, no expuestos al cliente.
- Fotografías y configuración persistentes bajo `C:\ProgramData\SnapStockApi`.
- Inicio automático y recuperación ante fallos mediante Windows Service.
- Kestrel limitado a `127.0.0.1:5000`; Cloudflare Tunnel publica HTTPS.

## Entregables

- API autónoma: `SnapStockApi\artifacts\SnapStockApi-win-x64.zip`.
- Carpeta publicada: `SnapStockApi\artifacts\publish`.
- Instalador del servicio dentro del ZIP: `deploy-windows-service.ps1`.
- APK de prueba: `SnapStockQR 3.0.0\build\app\outputs\apk\release\SnapStockQR_v3_0_0_TEST_DEBUG_SIGNED.apk`.

El APK está firmado para pruebas. Para distribución oficial se debe configurar una
clave propia mediante `SnapStockQR 3.0.0\android\key.properties.example`.

## Despliegue pendiente en el PC servidor

1. Rotar la credencial MySQL antigua.
2. Ampliar la columna de contraseñas:

   ```sql
   ALTER TABLE perfiles MODIFY COLUMN password VARCHAR(512) NOT NULL;
   ```

3. Copiar y descomprimir `SnapStockApi-win-x64.zip` en el PC servidor.
4. Abrir PowerShell como administrador dentro de la carpeta descomprimida.
5. Ejecutar:

   ```powershell
   $conexion = Read-Host 'Connection string MySQL' -AsSecureString
   .\deploy-windows-service.ps1 -DatabaseConnectionString $conexion
   ```

6. Confirmar que Cloudflare Tunnel apunta a `http://127.0.0.1:5000` y también tiene
   inicio automático.
7. Verificar `https://api.jahmantencion.cl/api/Registros/test`.
8. Instalar primero el APK de prueba y validar login, fotos, QR e impresión.
9. Crear y respaldar la clave Android definitiva antes de distribuir oficialmente.

## Validaciones completadas

- API: compilación Release sin errores ni advertencias.
- API: NuGet sin vulnerabilidades conocidas reportadas.
- API local: `/test` devuelve 200 y rutas protegidas devuelven 401 sin token.
- App: `flutter analyze` sin observaciones.
- App: prueba de interfaz aprobada.
- App: APK release de prueba compilado e iniciado en Android 16 sin excepciones.
- Código y artefactos: sin la credencial MySQL anterior ni referencias a Supabase.
- Servicio remoto: detenido; el dominio devuelve 502 mientras el origen está apagado.

No se probó el login real ni operaciones de escritura contra la nueva API porque el
servicio productivo está detenido y aún no se ha instalado esta versión en el otro PC.
