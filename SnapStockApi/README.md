# SnapStock API

API ASP.NET Core 8 para SnapStock QR. Expone autenticación, inventario, fotografías,
usuarios y categorías. La aplicación pública usa `https://api.jahmantencion.cl/api`.

## Diseño de producción

- El proceso se ejecuta como servicio de Windows `SnapStockApi`.
- Kestrel escucha solamente en `http://127.0.0.1:5000`.
- Cloudflare Tunnel publica ese origen mediante HTTPS.
- La configuración secreta vive en
  `C:\ProgramData\SnapStockApi\appsettings.Production.json`.
- Las fotografías viven en `C:\ProgramData\SnapStockApi\fotos` y no se borran al publicar.
- Todas las operaciones requieren JWT. Solo `GET /api/Registros/test` y
  `POST /api/Registros/login` son anónimas.
- `tipo = 1` representa usuario de consulta y `tipo = 2` administrador.

## Primera instalación o actualización

Abra PowerShell como administrador en la carpeta del proyecto:

```powershell
$conexion = Read-Host 'Connection string MySQL' -AsSecureString
.\scripts\deploy-windows-service.ps1 -DatabaseConnectionString $conexion
```

También puede copiar la carpeta `artifacts\publish` al PC servidor y ejecutar allí
`deploy-windows-service.ps1`; esa publicación es autónoma y no necesita instalar el
SDK de .NET.

En actualizaciones posteriores puede omitir `-DatabaseConnectionString`; el script
reutiliza la configuración protegida existente. También migra las fotografías de la
ubicación antigua si todavía existen.

Antes del primer despliegue protegido, confirme que la columna de contraseñas admite
los hashes PBKDF2:

```sql
ALTER TABLE perfiles MODIFY COLUMN password VARCHAR(512) NOT NULL;
```

Las contraseñas existentes siguen funcionando y se migran automáticamente a hash en
el primer login correcto de cada usuario.

El script publica una versión autónoma `win-x64`, registra inicio automático,
configura tres reinicios ante fallos e inicia el servicio. No configura Cloudflare;
el túnel debe apuntar a `http://127.0.0.1:5000` y tener su propio inicio automático.

## Comprobaciones

```powershell
Get-Service SnapStockApi
Invoke-RestMethod https://api.jahmantencion.cl/api/Registros/test
Get-WinEvent -LogName Application -MaxEvents 50 |
  Where-Object ProviderName -Like '*SnapStock*'
```

Un `GET /api/Registros` sin token debe responder `401`. Swagger solo se habilita en
el entorno `Development`.

## Desarrollo local

Copie `appsettings.Production.example.json` a una ubicación segura o use variables:

- `ConnectionStrings__SnapStock`
- `Jwt__SigningKey`
- `Storage__PhotosPath`
- `Storage__PublicBaseUrl`

Nunca guarde credenciales reales dentro del repositorio ni de `appsettings.json`.
