<#
.SYNOPSIS
    Creates an unsigned JSON Web Token for testing.
.DESCRIPTION
    Given a set of claims, creates a serialized unsigned JWT for use in testing.

    If no `iat` (issued at) claim is present, the current time will be added.
    `iat` is expected to be an epoch time but will be converted if it's found to
    be a DateTime or DateTimeOffset.

    If now `exp` (expires) claim is present, the token will expire in one year
    after the `iat` claim value. `exp` is expected to be an epoch time but will
    be converted if it's found to be a DateTime or DateTimeOffset.

    If no `iss` (issuer) claim is present, "https://localhost" will be added as
    the issuer.

    No other validation is done on the values or presence/absence of claims.
.PARAMETER Claims
    The dictionary of claims to add to the token. Should include `iat`, `exp`,
    and `iss` at a minimum. `iat` and `exp` are expected to be Int64 and will be
    converted if necessary.
.EXAMPLE
    PS> $claims = @{ "sub" = "test-user" }
    PS> New-UnsignedJwt -Claims $claims

    eyJhbGciOiJub25lIn0.eyJpc3MiOiJodHRwczovL2xvY2FsaG9zdCIsImV4cCI6MTY4Nzg4MjgwNCwiaWF0IjoxNjU2MzQ2ODA0LCJzdWIiOiJ0ZXN0LXVzZXIifQ.

    Generate token with a minimum set of claims. The issuer, issued-at, and
    expiration claims will be added before the token is generated. The above
    token will look something like:

    {
      "alg": "none"
    }
    {
      "iss": "https://localhost",
      "exp": 1687882804,
      "iat": 1656346804,
      "sub": "test-user"
    }

.EXAMPLE
    PS> $claims = @{ "sub" = "test-user"; "iat" = (Get-Date) }
    PS> New-UnsignedJwt -Claims $claims

    eyJhbGciOiJub25lIn0.eyJpc3MiOiJodHRwczovL2xvY2FsaG9zdCIsImV4cCI6MTY4Nzg4MzA1MSwiaWF0IjoxNjU2MzQ3MDUxLCJzdWIiOiJ0ZXN0LXVzZXIifQ.

    Generate token and convert the issued-at claim from a DateTime to Unix
    epoch. The expiration claim will be calculated automatically as one year
    after issued-at.

    {
      "alg": "none"
    }
    {
      "iss": "https://localhost",
      "exp": 1687883051,
      "iat": 1656347051,
      "sub": "test-user"
    }
#>
Function New-UnsignedJwt {
    [CmdletBinding(SupportsShouldProcess = $False)]
    Param(
        [Parameter(Mandatory = $True, Position = 1, ValueFromPipeline = $True)]
        [ValidateNotNull()]
        [System.Collections.IDictionary]
        $Claims
    )

    Begin {
        Function JwtEncode {
            Param(
                [Parameter(Mandatory = $True)]
                [ValidateNotNull()]
                $ToEncode
            )

            $stringified = $ToEncode | ConvertTo-Json -Compress
            [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($stringified)).Replace('=','')
        }
        $headerEnvelope = @{
            "alg" = "none"
        }
        $header = JwtEncode -ToEncode $headerEnvelope
    }

    Process {
        $iat = $Claims['iat']
        If($null -eq $iat)
        {
            # There's no iat claim - issue it right now as DateTimeOffset.
            $iat = [DateTimeOffset]::Now
            Write-Verbose "Adding 'iat' claim $iat."
        }
        If($iat.GetType() -eq [DateTime])
        {
            # The iat is a DateTime - convert to DateTimeOffset.
            $iat = New-Object -TypeName DateTimeOffset -ArgumentList $iat
            Write-Verbose "Converting 'iat' to DateTimeOffset."
        }
        If($iat.GetType() -eq [DateTimeOffset])
        {
            # Convert to epoch time - this will fall through from the earlier settings or catch a manually assigned value.
            $iat = $iat.ToUnixTimeSeconds()
            Write-Verbose "Converting 'iat' to epoch time."
        }
        Try {
            $iat = [Convert]::ToInt64($iat)
        }
        Catch {
            throw "Unable to convert 'iat' claim $iat to Int64."
        }

        Write-Verbose "'iat' claim is $iat."
        $Claims['iat'] = $iat

        $exp = $Claims['exp']
        If ($null -eq $exp) {
            # There's no exp claim - set it as one year after iat.
            $exp = [DateTimeOffset]::FromUnixTimeSeconds($iat).AddYears(1)
            Write-Verbose "Adding 'exp' claim $exp."
        }
        If ($exp.GetType() -eq [DateTime]) {
            # The exp is a DateTime - convert to DateTimeOffset.
            $exp = New-Object -TypeName DateTimeOffset -ArgumentList $exp
            Write-Verbose "Converting 'exp' to DateTimeOffset."
        }
        If ($exp.GetType() -eq [DateTimeOffset]) {
            # Convert to epoch time - this will fall through from the earlier settings or catch a manually assigned value.
            $exp = $exp.ToUnixTimeSeconds()
            Write-Verbose "Converting 'exp' to epoch time."
        }
        Try {
            $exp = [Convert]::ToInt64($exp)
        }
        Catch {
            throw "Unable to convert 'exp' claim $exp to Int64."
        }

        Write-Verbose "'exp' claim is $exp."
        $Claims['exp'] = $exp

        $iss = $Claims['iss']
        If ($null -eq $iss) {
            # There's no iss claim - issue it as localhost.
            $iss = "https://localhost"
            Write-Verbose "Adding 'iss' claim $iss."
            $Claims['iss'] = $iss
        }

        $body = JwtEncode -ToEncode $Claims
        "$header`.$body`."
    }
}
