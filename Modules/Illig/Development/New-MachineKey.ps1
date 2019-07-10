<#
.Synopsis
   Creates a new machine key element for use in web.config files.
.PARAMETER Decryption
   Indicates the decryption algorithm that should be used for the machine key: AES, DES, 3DES.
.PARAMETER Validation
   Indicates the request validation algorithm that should be used: MD5, SHA1, HMACSHA256, HMACSHA384, HMACSHA512.
.DESCRIPTION
   Generates new machine key data in XML element format that can be used in a web.config file in an ASP.NET web site.
.EXAMPLE
   New-MachineKey
.EXAMPLE
   New-MachineKey -Validation SHA1
#>
function New-MachineKey {
    [CmdletBinding(HelpUri = 'https://support.microsoft.com/en-us/kb/2915218#AppendixA')]
    [OutputType([String])]
    Param
    (
        [ValidateSet("AES", "DES", "3DES")]
        [string]$Decryption = 'AES',
        [ValidateSet("MD5", "SHA1", "HMACSHA256", "HMACSHA384", "HMACSHA512")]
        [string]$Validation = 'HMACSHA256',
        [switch]$PrettyPrint
    )

    Process {
        function BinaryToHex {
            [CmdLetBinding()]
            Param($bytes)
            Process {
                $builder = new-object System.Text.StringBuilder
                foreach ($b in $bytes) {
                    $builder = $builder.AppendFormat([System.Globalization.CultureInfo]::InvariantCulture, "{0:X2}", $b)
                }
                $builder
            }
        }

        switch ($Decryption) {
            "AES" { $decryptionObject = new-object System.Security.Cryptography.AesCryptoServiceProvider }
            "DES" { $decryptionObject = new-object System.Security.Cryptography.DESCryptoServiceProvider }
            "3DES" { $decryptionObject = new-object System.Security.Cryptography.TripleDESCryptoServiceProvider }
        }

        $decryptionObject.GenerateKey()
        $decryptionKey = BinaryToHex($decryptionObject.Key)
        $decryptionObject.Dispose()

        switch ($Validation) {
            "MD5" { $validationObject = new-object System.Security.Cryptography.HMACMD5 }
            "SHA1" { $validationObject = new-object System.Security.Cryptography.HMACSHA1 }
            "HMACSHA256" { $validationObject = new-object System.Security.Cryptography.HMACSHA256 }
            "HMACSHA385" { $validationObject = new-object System.Security.Cryptography.HMACSHA384 }
            "HMACSHA512" { $validationObject = new-object System.Security.Cryptography.HMACSHA512 }
        }

        $validationKey = BinaryToHex($validationObject.Key)
        $validationObject.Dispose()
        if ($PrettyPrint) {
            $space = [System.Environment]::NewLine + "            "
        }
        else {
            $space = " "
        }

        [string]::Format([System.Globalization.CultureInfo]::InvariantCulture,
            "<machineKey decryption=`"{0}`"{4}decryptionKey=`"{1}`"{4}validation=`"{2}`"{4}validationKey=`"{3}`" />",
            $Decryption.ToUpperInvariant(),
            $decryptionKey,
            $Validation.ToUpperInvariant(),
            $validationKey,
            $space)
    }
}
