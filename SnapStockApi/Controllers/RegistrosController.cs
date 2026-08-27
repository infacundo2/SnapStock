using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using MySql.Data.MySqlClient;
using SnapStockApi.Services;
using System.Data.Common;
using System.Security.Claims;

namespace SnapStockApi.Controllers;

[ApiController]
[Authorize]
[Route("api/[controller]")]
public sealed class RegistrosController : ControllerBase
{
    private const long MaxPhotoBytes = 10 * 1024 * 1024;
    private const int MaxPhotosPerRequest = 8;

    private readonly string _connectionString;
    private readonly string _photosPath;
    private readonly string _publicBaseUrl;
    private readonly HashSet<string> _managedPhotoAuthorities;
    private readonly string _deploymentMode;
    private readonly PasswordService _passwords;
    private readonly TokenService _tokens;
    private readonly ILogger<RegistrosController> _logger;

    public RegistrosController(
        IConfiguration configuration,
        PasswordService passwords,
        TokenService tokens,
        ILogger<RegistrosController> logger)
    {
        _connectionString = configuration.GetConnectionString("SnapStock")
            ?? throw new InvalidOperationException("Falta ConnectionStrings:SnapStock.");
        var configuredPhotosPath = configuration["Storage:PhotosPath"];
        _photosPath = string.IsNullOrWhiteSpace(configuredPhotosPath)
            ? Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
                "SnapStockApi",
                "fotos")
            : Path.GetFullPath(configuredPhotosPath);
        var useLocal = configuration.GetValue("UseLocal", false);
        var localBaseUrl = (configuration["LocalPublicBaseUrl"]
            ?? "https://192.168.140.171").TrimEnd('/');
        var publicBaseUrl = (configuration["PublicPublicBaseUrl"]
            ?? configuration["Storage:PublicBaseUrl"]
            ?? "https://api.jahmantencion.cl").TrimEnd('/');
        _publicBaseUrl = useLocal ? localBaseUrl : publicBaseUrl;
        _deploymentMode = useLocal ? "local" : "public";
        _managedPhotoAuthorities = new[] { localBaseUrl, publicBaseUrl }
            .Select(value => Uri.TryCreate(value, UriKind.Absolute, out var uri)
                ? uri.Authority
                : null)
            .Where(value => !string.IsNullOrWhiteSpace(value))
            .Cast<string>()
            .ToHashSet(StringComparer.OrdinalIgnoreCase);
        _passwords = passwords;
        _tokens = tokens;
        _logger = logger;
        Directory.CreateDirectory(_photosPath);
    }

    [AllowAnonymous]
    [HttpGet("test")]
    public IActionResult Test() => Ok(new
    {
        message = "SnapStock API v3.0.0 disponible",
        fecha = DateTimeOffset.UtcNow,
        mode = _deploymentMode,
        publicBaseUrl = _publicBaseUrl
    });

    [Authorize(Roles = "Admin")]
    [HttpGet]
    public async Task<IActionResult> GetAll(CancellationToken cancellationToken)
    {
        var records = new List<object>();
        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            const string sql = """
                SELECT id, uuid, nombre, fecha, observaciones, categoria, foto_paths
                FROM registros
                ORDER BY id DESC
                """;
            await using var command = new MySqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                records.Add(ReadRecord(reader));
            }

            return Ok(records);
        }
        catch (Exception exception)
        {
            return ServerError(exception, "obtener los registros");
        }
    }

    [HttpGet("{uuid:guid}")]
    public async Task<IActionResult> GetByUuid(Guid uuid, CancellationToken cancellationToken)
    {
        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            const string sql = """
                SELECT id, uuid, nombre, fecha, observaciones, categoria, foto_paths
                FROM registros
                WHERE uuid = @uuid
                LIMIT 1
                """;
            await using var command = new MySqlCommand(sql, connection);
            command.Parameters.AddWithValue("@uuid", uuid.ToString());
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            return await reader.ReadAsync(cancellationToken)
                ? Ok(ReadRecord(reader))
                : NotFound(new { message = "No se encontró el registro." });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "buscar el registro");
        }
    }

    [AllowAnonymous]
    [EnableRateLimiting("login")]
    [HttpPost("login")]
    public async Task<IActionResult> Login(
        [FromForm] string nombre,
        [FromForm] string password,
        CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(nombre) || string.IsNullOrEmpty(password))
        {
            return Unauthorized(new { message = "Usuario o contraseña incorrectos." });
        }

        try
        {
            int id;
            string storedPassword;
            string storedName;
            int type;

            await using (var connection = CreateConnection())
            {
                await connection.OpenAsync(cancellationToken);
                const string sql = """
                    SELECT id, nombre, password, tipo
                    FROM perfiles
                    WHERE nombre = @nombre
                    LIMIT 1
                    """;
                await using var command = new MySqlCommand(sql, connection);
                command.Parameters.AddWithValue("@nombre", nombre.Trim());
                await using var reader = await command.ExecuteReaderAsync(cancellationToken);
                if (!await reader.ReadAsync(cancellationToken))
                {
                    return Unauthorized(new { message = "Usuario o contraseña incorrectos." });
                }

                id = Convert.ToInt32(reader["id"]);
                storedName = reader["nombre"].ToString() ?? nombre.Trim();
                storedPassword = reader["password"].ToString() ?? string.Empty;
                type = Convert.ToInt32(reader["tipo"]);
            }

            if (!_passwords.Verify(storedPassword, password, out var shouldUpgrade))
            {
                return Unauthorized(new { message = "Usuario o contraseña incorrectos." });
            }

            if (shouldUpgrade)
            {
                try
                {
                    await UpgradePassword(id, password, cancellationToken);
                }
                catch (Exception exception)
                {
                    // El acceso sigue funcionando; el error queda visible para corregir el esquema de BD.
                    _logger.LogError(exception, "No se pudo migrar la contraseña del usuario {UserId}", id);
                }
            }

            var issued = _tokens.Create(id, storedName, type);
            return Ok(new
            {
                nombre = storedName,
                tipo = type,
                token = issued.Token,
                expiresAt = issued.ExpiresAt
            });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "iniciar sesión");
        }
    }

    [Authorize(Roles = "Admin")]
    [RequestSizeLimit(80_000_000)]
    [HttpPost("guardar")]
    public async Task<IActionResult> Guardar(
        [FromForm] string uuid,
        [FromForm] string nombre,
        [FromForm] string fecha,
        [FromForm] string observaciones,
        [FromForm] string categoria,
        [FromForm] string? foto_paths,
        CancellationToken cancellationToken)
    {
        if (!Guid.TryParse(uuid, out _) ||
            string.IsNullOrWhiteSpace(nombre) || nombre.Length > 200 ||
            string.IsNullOrWhiteSpace(categoria) || categoria.Length > 100 ||
            observaciones.Length > 4000 || fecha.Length > 50)
        {
            return BadRequest(new { message = "Los datos del registro no son válidos." });
        }

        var files = Request.Form.Files;
        if (files.Count > MaxPhotosPerRequest)
        {
            return BadRequest(new { message = $"Se permiten hasta {MaxPhotosPerRequest} fotos por operación." });
        }

        var retainedUrls = (foto_paths ?? string.Empty)
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(IsManagedPhotoUrl)
            .Select(ToCurrentManagedPhotoUrl)
            .Distinct(StringComparer.OrdinalIgnoreCase)
            .ToList();
        var newUrls = new List<string>();
        var newFiles = new List<string>();
        var previousUrls = new List<string>();
        var committed = false;

        try
        {
            foreach (var file in files)
            {
                var extension = GetSafeImageExtension(file);
                if (extension is null ||
                    file.Length <= 0 ||
                    file.Length > MaxPhotoBytes ||
                    !await HasValidImageSignature(file, extension, cancellationToken))
                {
                    return BadRequest(new { message = "Cada foto debe ser JPG, PNG o WEBP y pesar como máximo 10 MB." });
                }

                var fileName = $"{Guid.NewGuid():N}{extension}";
                var physicalPath = Path.Combine(_photosPath, fileName);
                await using var stream = new FileStream(
                    physicalPath,
                    FileMode.CreateNew,
                    FileAccess.Write,
                    FileShare.None,
                    81920,
                    useAsync: true);
                await file.CopyToAsync(stream, cancellationToken);
                newFiles.Add(physicalPath);
                newUrls.Add($"{_publicBaseUrl}/fotos/{fileName}");
            }

            var finalUrls = retainedUrls.Concat(newUrls).ToList();
            var pathsForDatabase = string.Join(',', finalUrls);

            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            await using var transaction = await connection.BeginTransactionAsync(cancellationToken);

            const string selectSql = "SELECT foto_paths FROM registros WHERE uuid = @uuid LIMIT 1";
            await using (var select = new MySqlCommand(selectSql, connection, transaction))
            {
                select.Parameters.AddWithValue("@uuid", uuid);
                var previous = (await select.ExecuteScalarAsync(cancellationToken))?.ToString() ?? string.Empty;
                previousUrls = previous
                    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
                    .Where(IsManagedPhotoUrl)
                    .Select(ToCurrentManagedPhotoUrl)
                    .ToList();
            }

            const string upsertSql = """
                INSERT INTO registros (uuid, nombre, fecha, observaciones, categoria, foto_paths)
                VALUES (@uuid, @nombre, @fecha, @observaciones, @categoria, @fotos)
                ON DUPLICATE KEY UPDATE
                    nombre = @nombre,
                    fecha = @fecha,
                    observaciones = @observaciones,
                    categoria = @categoria,
                    foto_paths = @fotos
                """;
            await using (var command = new MySqlCommand(upsertSql, connection, transaction))
            {
                command.Parameters.AddWithValue("@uuid", uuid);
                command.Parameters.AddWithValue("@nombre", nombre.Trim());
                command.Parameters.AddWithValue("@fecha", fecha.Trim());
                command.Parameters.AddWithValue("@observaciones", observaciones.Trim());
                command.Parameters.AddWithValue("@categoria", categoria.Trim());
                command.Parameters.AddWithValue("@fotos", pathsForDatabase);
                await command.ExecuteNonQueryAsync(cancellationToken);
            }

            await transaction.CommitAsync(cancellationToken);
            committed = true;

            foreach (var removedUrl in previousUrls.Except(finalUrls, StringComparer.OrdinalIgnoreCase))
            {
                DeleteManagedPhoto(removedUrl);
            }

            return Ok(new { message = "OK", paths = pathsForDatabase });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "guardar el registro");
        }
        finally
        {
            if (!committed)
            {
                foreach (var file in newFiles)
                {
                    TryDelete(file);
                }
            }
        }
    }

    [Authorize(Roles = "Admin")]
    [HttpDelete("eliminar/{uuid:guid}")]
    public async Task<IActionResult> Eliminar(Guid uuid, CancellationToken cancellationToken)
    {
        try
        {
            string paths;
            int affected;
            await using (var connection = CreateConnection())
            {
                await connection.OpenAsync(cancellationToken);
                await using var transaction = await connection.BeginTransactionAsync(cancellationToken);
                const string selectSql = "SELECT foto_paths FROM registros WHERE uuid = @uuid LIMIT 1";
                await using (var select = new MySqlCommand(selectSql, connection, transaction))
                {
                    select.Parameters.AddWithValue("@uuid", uuid.ToString());
                    paths = (await select.ExecuteScalarAsync(cancellationToken))?.ToString() ?? string.Empty;
                }

                const string deleteSql = "DELETE FROM registros WHERE uuid = @uuid";
                await using (var delete = new MySqlCommand(deleteSql, connection, transaction))
                {
                    delete.Parameters.AddWithValue("@uuid", uuid.ToString());
                    affected = await delete.ExecuteNonQueryAsync(cancellationToken);
                }

                await transaction.CommitAsync(cancellationToken);
            }

            if (affected == 0)
            {
                return NotFound(new { message = "No se encontró el registro." });
            }

            foreach (var url in paths.Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries))
            {
                DeleteManagedPhoto(url);
            }

            return Ok(new { message = "Eliminado correctamente del servidor" });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "eliminar el registro");
        }
    }

    [Authorize(Roles = "Admin")]
    [HttpGet("usuarios")]
    public async Task<IActionResult> GetUsuarios(CancellationToken cancellationToken)
    {
        try
        {
            var users = new List<object>();
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            const string sql = "SELECT id, nombre, tipo FROM perfiles ORDER BY nombre";
            await using var command = new MySqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                users.Add(new
                {
                    id = reader["id"],
                    nombre = reader["nombre"],
                    tipo = reader["tipo"]
                });
            }

            return Ok(users);
        }
        catch (Exception exception)
        {
            return ServerError(exception, "obtener los usuarios");
        }
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("usuarios/crear")]
    public async Task<IActionResult> CrearUsuario(
        [FromForm] string nombre,
        [FromForm] string password,
        [FromForm] int tipo,
        CancellationToken cancellationToken)
    {
        return await CreateUser(nombre, password, tipo, cancellationToken);
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("usuarios/crear-admin")]
    public async Task<IActionResult> CrearAdmin(
        [FromForm] string nombre,
        [FromForm] string password,
        CancellationToken cancellationToken)
    {
        return await CreateUser(nombre, password, 2, cancellationToken);
    }

    [Authorize(Roles = "Admin")]
    [HttpDelete("usuarios/{id:int}")]
    public async Task<IActionResult> EliminarUsuario(int id, CancellationToken cancellationToken)
    {
        if (User.FindFirstValue(ClaimTypes.NameIdentifier) == id.ToString())
        {
            return BadRequest(new { message = "No puede eliminar su propio usuario." });
        }

        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);

            const string targetSql = "SELECT tipo FROM perfiles WHERE id = @id LIMIT 1";
            int? targetType;
            await using (var target = new MySqlCommand(targetSql, connection))
            {
                target.Parameters.AddWithValue("@id", id);
                var value = await target.ExecuteScalarAsync(cancellationToken);
                targetType = value is null ? null : Convert.ToInt32(value);
            }

            if (targetType is null)
            {
                return NotFound(new { message = "No se encontró el usuario." });
            }

            if (targetType == 2)
            {
                const string countSql = "SELECT COUNT(*) FROM perfiles WHERE tipo = 2";
                await using var count = new MySqlCommand(countSql, connection);
                var adminCount = Convert.ToInt32(await count.ExecuteScalarAsync(cancellationToken));
                if (adminCount <= 1)
                {
                    return Conflict(new { message = "No se puede eliminar el último administrador." });
                }
            }

            const string deleteSql = "DELETE FROM perfiles WHERE id = @id";
            await using var command = new MySqlCommand(deleteSql, connection);
            command.Parameters.AddWithValue("@id", id);
            await command.ExecuteNonQueryAsync(cancellationToken);
            return Ok(new { message = "Usuario eliminado." });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "eliminar el usuario");
        }
    }

    [Authorize(Roles = "Admin")]
    [HttpGet("categorias")]
    public async Task<IActionResult> GetCategorias(CancellationToken cancellationToken)
    {
        try
        {
            var categories = new List<string>();
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            const string sql = """
                SELECT DISTINCT categoria
                FROM registros
                WHERE categoria IS NOT NULL AND categoria <> ''
                ORDER BY categoria
                """;
            await using var command = new MySqlCommand(sql, connection);
            await using var reader = await command.ExecuteReaderAsync(cancellationToken);
            while (await reader.ReadAsync(cancellationToken))
            {
                var category = reader["categoria"].ToString();
                if (!string.IsNullOrWhiteSpace(category))
                {
                    categories.Add(category);
                }
            }

            return Ok(categories);
        }
        catch (Exception exception)
        {
            return ServerError(exception, "obtener las categorías");
        }
    }

    private async Task<IActionResult> CreateUser(
        string name,
        string password,
        int type,
        CancellationToken cancellationToken)
    {
        name = name.Trim();
        if (name.Length is < 2 or > 100 || password.Length is < 8 or > 200 || type is not (1 or 2))
        {
            return BadRequest(new
            {
                message = "El nombre debe tener 2 a 100 caracteres y la contraseña al menos 8 caracteres."
            });
        }

        try
        {
            await using var connection = CreateConnection();
            await connection.OpenAsync(cancellationToken);
            const string sql = """
                INSERT INTO perfiles (nombre, password, tipo)
                VALUES (@nombre, @password, @tipo)
                """;
            await using var command = new MySqlCommand(sql, connection);
            command.Parameters.AddWithValue("@nombre", name);
            command.Parameters.AddWithValue("@password", _passwords.Hash(password));
            command.Parameters.AddWithValue("@tipo", type);
            await command.ExecuteNonQueryAsync(cancellationToken);
            return Ok(new { message = "Usuario creado." });
        }
        catch (MySqlException exception) when (exception.Number == 1062)
        {
            return Conflict(new { message = "Ya existe un usuario con ese nombre." });
        }
        catch (Exception exception)
        {
            return ServerError(exception, "crear el usuario");
        }
    }

    private async Task UpgradePassword(int id, string password, CancellationToken cancellationToken)
    {
        await using var connection = CreateConnection();
        await connection.OpenAsync(cancellationToken);
        const string sql = "UPDATE perfiles SET password = @password WHERE id = @id";
        await using var command = new MySqlCommand(sql, connection);
        command.Parameters.AddWithValue("@password", _passwords.Hash(password));
        command.Parameters.AddWithValue("@id", id);
        await command.ExecuteNonQueryAsync(cancellationToken);
    }

    private MySqlConnection CreateConnection() => new(_connectionString);

    private object ReadRecord(DbDataReader reader) => new
    {
        id = reader["id"],
        uuid = reader["uuid"],
        nombre = reader["nombre"],
        fecha = reader["fecha"],
        observaciones = reader["observaciones"],
        categoria = reader["categoria"],
        foto_paths = NormalizePhotoPaths(reader["foto_paths"]?.ToString() ?? string.Empty)
    };

    private bool IsManagedPhotoUrl(string value)
    {
        if (!Uri.TryCreate(value, UriKind.Absolute, out var candidate))
        {
            return false;
        }

        return candidate.Scheme == Uri.UriSchemeHttps &&
               _managedPhotoAuthorities.Contains(candidate.Authority) &&
               candidate.AbsolutePath.StartsWith("/fotos/", StringComparison.OrdinalIgnoreCase);
    }

    private string ToCurrentManagedPhotoUrl(string value)
    {
        return Uri.TryCreate(value, UriKind.Absolute, out var parsed)
            ? $"{_publicBaseUrl}{parsed.AbsolutePath}"
            : value;
    }

    private string NormalizePhotoPaths(string value)
    {
        return string.Join(',', value
            .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries)
            .Where(IsManagedPhotoUrl)
            .Select(ToCurrentManagedPhotoUrl)
            .Distinct(StringComparer.OrdinalIgnoreCase));
    }

    private static string? GetSafeImageExtension(IFormFile file)
    {
        return file.ContentType.ToLowerInvariant() switch
        {
            "image/jpeg" or "image/jpg" => ".jpg",
            "image/png" => ".png",
            "image/webp" => ".webp",
            _ => null
        };
    }

    private static async Task<bool> HasValidImageSignature(
        IFormFile file,
        string extension,
        CancellationToken cancellationToken)
    {
        var header = new byte[12];
        await using var stream = file.OpenReadStream();
        var read = await stream.ReadAsync(header.AsMemory(0, header.Length), cancellationToken);
        return extension switch
        {
            ".jpg" => read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF,
            ".png" => read >= 8 && header.AsSpan(0, 8).SequenceEqual(
                new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }),
            ".webp" => read >= 12 &&
                       header.AsSpan(0, 4).SequenceEqual("RIFF"u8) &&
                       header.AsSpan(8, 4).SequenceEqual("WEBP"u8),
            _ => false
        };
    }

    private void DeleteManagedPhoto(string url)
    {
        if (!IsManagedPhotoUrl(url) || !Uri.TryCreate(url, UriKind.Absolute, out var parsed))
        {
            return;
        }

        var fileName = Path.GetFileName(parsed.LocalPath);
        if (!string.IsNullOrWhiteSpace(fileName))
        {
            TryDelete(Path.Combine(_photosPath, fileName));
        }
    }

    private void TryDelete(string path)
    {
        try
        {
            if (System.IO.File.Exists(path))
            {
                System.IO.File.Delete(path);
            }
        }
        catch (Exception exception)
        {
            _logger.LogWarning(exception, "No se pudo eliminar el archivo {Path}", path);
        }
    }

    private ObjectResult ServerError(Exception exception, string operation)
    {
        _logger.LogError(exception, "Error al {Operation}", operation);
        return Problem(
            statusCode: StatusCodes.Status500InternalServerError,
            title: $"No fue posible {operation}.");
    }
}
