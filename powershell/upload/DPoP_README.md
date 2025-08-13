# DPoP (Demonstration of Proof-of-Possession) Integration - Upload Script

This PowerShell upload script now supports DPoP (Demonstration of Proof-of-Possession) functionality for enhanced security when uploading files to the File API.

## What is DPoP?

DPoP is a security mechanism that provides proof-of-possession for access tokens. It helps prevent token replay attacks by binding access tokens to a specific cryptographic key pair. Each API request includes a DPoP proof token that demonstrates possession of the private key associated with the access token.

## Configuration

To enable DPoP, update your `config.xml` file with the following DPoP section:

```xml
<DPoP>
    <!-- Enable DPoP (Demonstration of Proof-of-Possession) for enhanced security -->
    <Enabled>true</Enabled>
</DPoP>
```

### Configuration Parameters

- **Enabled**: Set to `true` to enable DPoP functionality, `false` to disable

## How It Works

1. **Key Generation**: When DPoP is enabled, the script automatically generates fresh DPoP settings for each execution:
   - An RSA key pair with 2048-bit key size
   - RSA modulus (N) and exponent (E) components for JWK format

2. **Session-based Keys**: Keys are generated in memory and exist only for the duration of the script execution, providing enhanced security

3. **DPoP Token Generation**: For each API request, a DPoP proof token is generated that includes:
   - HTTP method (POST, PUT, etc.)
   - Target URI
   - Timestamp (iat - issued at)
   - Unique identifier (jti - JWT ID)
   - Public key information (JWK format with RSA modulus and exponent)

4. **Request Headers**: Each API request includes:
   - `Authorization: Bearer <access_token>` (standard OAuth token)
   - `DPoP: <dpop_proof_token>` (DPoP proof)

## Upload-Specific DPoP Implementation

The upload script applies DPoP to:
- **Initial Upload Requests**: POST requests for starting file uploads
- **Chunk Upload Requests**: PUT requests for uploading file chunks
- **Completion Requests**: Final requests to complete multi-part uploads

Each upload operation gets its own fresh DPoP proof token, ensuring maximum security for file transfer operations.

## Security Benefits

- **Token Binding**: Access tokens are cryptographically bound to the client's key pair
- **Replay Protection**: Each DPoP proof includes a timestamp and is unique to the specific request
- **Man-in-the-Middle Protection**: Even if tokens are intercepted, they cannot be used without the private key
- **Enhanced Session Security**: Fresh keys for each execution prevent key compromise across sessions
- **Upload Integrity**: Each file upload chunk is cryptographically protected

## Implementation Details

The PowerShell implementation includes the following classes:

- `DPoPSettings`: Manages DPoP configuration and generates fresh RSA key pairs
- `DPoPKeyGenerator`: Generates RSA key pairs with 2048-bit key size using .NET cryptography
- `DPoPTokenGenerator`: Creates JWT-format DPoP proof tokens with RSA-PSS signatures
- `DPoPManager`: Handles creation of fresh DPoP settings for each execution

### Technical Specifications

**Cryptographic Algorithm:**
- **Key Type**: RSA with 2048-bit key size
- **Signature Algorithm**: RS256 (RSA with SHA-256)
- **JWT Type**: `dpop+jwt`

**JWK (JSON Web Key) Structure:**
```json
{
  "kty": "RSA",
  "n": "<base64url-encoded RSA modulus>",
  "e": "<base64url-encoded RSA exponent>"
}
```

**DPoP JWT Header:**
```json
{
  "alg": "RS256",
  "typ": "dpop+jwt",
  "jwk": {
    "kty": "RSA",
    "n": "...",
    "e": "..."
  }
}
```

**DPoP JWT Payload:**
```json
{
  "jti": "<unique-guid>",
  "htm": "<HTTP-method>",
  "htu": "<target-uri>",
  "iat": <timestamp>,
  "ath": "<SHA256-hash-of-access-token>" // (when access token is available)
}
```

**Access Token Binding:**
- When an access token is available, its SHA-256 hash is included in the `ath` (access token hash) claim
- This cryptographically binds the DPoP proof to the specific access token
- The hash is base64url-encoded without padding

## Troubleshooting

### Common Issues

1. **Cryptography Errors**: 
   - Ensure .NET Framework/Core supports RSA cryptographic operations
   - Verify that the system has sufficient entropy for secure key generation
   - Check that RSA key size (2048-bit) is supported by the runtime
2. **Permission Errors**: Verify the script has necessary permissions to create cryptographic objects
3. **Upload Failures**: If uploads fail with DPoP enabled, check that the API endpoint supports DPoP with RS256 algorithm
4. **JWT Signature Errors**: Ensure RSA key components (modulus/exponent) are correctly base64url-encoded

### Logging

When DPoP is enabled, additional log entries will appear:
- DPoP initialization messages
- Fresh key generation information
- DPoP token generation status
- Cleanup and disposal messages

## Migration from Non-DPoP

To migrate an existing upload configuration:

1. Add the DPoP section to your `config.xml`
2. Set `Enabled` to `true`
3. Run the script - fresh keys will be automatically generated for each execution

The script maintains backward compatibility and will work without DPoP configuration (DPoP disabled by default).

## Security Considerations

- **Session-based Security**: RSA key pairs (2048-bit) are generated fresh for each script execution, providing enhanced security
- **Memory-only Storage**: Private keys exist only in memory during script execution
- **No Persistent Key Storage**: Eliminates risks associated with key file storage and management
- **Upload Protection**: All file upload operations are cryptographically protected with unique DPoP proofs
- **Strong Cryptography**: Uses RSA-2048 with SHA-256 for robust cryptographic security
- **Token Binding**: Access tokens are cryptographically bound using SHA-256 hash in the `ath` claim

## Performance Impact

DPoP adds minimal overhead to upload operations:
- Key generation occurs once per script execution
- DPoP token generation adds ~1-2ms per API request
- No significant impact on file transfer speeds
- Memory usage increase is negligible
