# Cadastro local de uma tag na credencial da seed. Nao executa a seed nem concede
# autorizacoes novas. O backend continua validando usuario, local, prazo e usos.
[CmdletBinding()]
param(
    [ValidateRange(5, 600)]
    [int]$TimeoutSeconds = 120
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$docker = (Get-Command docker.exe -ErrorAction Stop).Source
$composeArgs = @(
    '--project-directory', $projectRoot,
    '-f', (Join-Path $projectRoot 'infra/docker-compose.dev.yml'),
    '-f', (Join-Path $projectRoot 'infra/docker-compose.nfc.local.yml')
)
$credentialId = 'a1000000-0000-4000-8000-000000000006'
$userId = 'a1000000-0000-4000-8000-000000000002'

$services = & $docker compose @composeArgs ps --status running --services
if ($LASTEXITCODE -ne 0) { throw 'Nao foi possivel consultar o Docker.' }
if ('mosquitto' -notin $services -or 'postgres' -notin $services) {
    throw 'PostgreSQL e Mosquitto precisam estar em execucao antes do cadastro.'
}

Write-Host 'Retire a tag do leitor por um segundo e aproxime a tag que deseja cadastrar.'
Write-Host "Aguardando uma leitura do terminal-01 por ate $TimeoutSeconds segundos..."

$payload = & $docker compose @composeArgs exec -T mosquitto mosquitto_sub `
    -h localhost -p 1883 -t terminals/terminal-01/access-events -C 1 -W $TimeoutSeconds
if ($LASTEXITCODE -ne 0) {
    throw 'Nenhuma leitura recebida. Nada foi cadastrado; retire a tag e tente novamente.'
}

$message = ($payload -join "`n") | ConvertFrom-Json -ErrorAction Stop
if ($message.v -ne 1 -or $message.type -ne 'nfc_read' -or
    $message.terminalId -ne 'terminal-01' -or $message.uid -isnot [string]) {
    throw 'A mensagem recebida nao e uma tentativa NFC valida. Nada foi cadastrado.'
}
$uid = $message.uid.Trim().ToUpperInvariant()
if ($uid -notmatch '^(?:[0-9A-F]{8}|[0-9A-F]{14}|[0-9A-F]{20})$') {
    throw 'UID invalido. Nada foi cadastrado.'
}

$sha = [System.Security.Cryptography.SHA256]::Create()
try {
    $hash = ($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($uid)) |
        ForEach-Object { $_.ToString('x2') }) -join ''
} finally {
    $sha.Dispose()
}

# UID original nunca e gravado no banco nem impresso pelo script.
$sql = @"
UPDATE "Credential"
SET "valueHash" = '$hash', "revokedAt" = NULL
WHERE id = '$credentialId'
  AND "userId" = '$userId'
  AND type = 'NFC'
RETURNING id;
"@
$result = $sql | & $docker compose @composeArgs exec -T postgres psql `
    -U abp4 -d abp4 -v ON_ERROR_STOP=1 -t -A
if ($LASTEXITCODE -ne 0) {
    throw 'O banco recusou o cadastro. A operacao nao foi concluida.'
}
$rows = @($result | ForEach-Object { $_.Trim() })
if ($credentialId -notin $rows) {
    throw 'Credencial NFC do usuario demo nao encontrada. Nenhuma linha foi alterada.'
}

Write-Host 'Tag associada ao usuario de demonstracao.'
Write-Host 'Retire a tag por um segundo e aproxime novamente para testar a autorizacao.'
Write-Host 'Nao execute a seed novamente: ela restaura a tag ficticia.'
