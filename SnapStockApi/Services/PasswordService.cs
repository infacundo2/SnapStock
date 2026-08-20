using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Identity;

namespace SnapStockApi.Services;

public sealed class PasswordService
{
    private readonly PasswordHasher<object> _hasher = new();
    private static readonly object UserMarker = new();

    public string Hash(string password) => _hasher.HashPassword(UserMarker, password);

    public bool Verify(string storedValue, string suppliedPassword, out bool shouldUpgrade)
    {
        shouldUpgrade = false;

        if (storedValue.StartsWith("AQAAAA", StringComparison.Ordinal))
        {
            try
            {
                var result = _hasher.VerifyHashedPassword(UserMarker, storedValue, suppliedPassword);
                shouldUpgrade = result == PasswordVerificationResult.SuccessRehashNeeded;
                return result != PasswordVerificationResult.Failed;
            }
            catch (FormatException)
            {
                return false;
            }
        }

        // Compatibilidad: el primer login correcto migra la contraseña antigua a PBKDF2.
        var storedDigest = SHA256.HashData(Encoding.UTF8.GetBytes(storedValue));
        var suppliedDigest = SHA256.HashData(Encoding.UTF8.GetBytes(suppliedPassword));
        var valid = CryptographicOperations.FixedTimeEquals(storedDigest, suppliedDigest);
        shouldUpgrade = valid;
        return valid;
    }
}
