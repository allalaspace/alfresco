# Sauvegarde la base PostgreSQL et le contenu Alfresco (volume alfresco_data).
# Elasticsearch se reconstruit via batch-indexing ; il n'est pas inclus.
# Usage, depuis n'importe quel dossier : .\scripts\backup.ps1

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

$DbUser = "alfresco"
$DbName = "alfresco"
$EnvFile = Join-Path $Root ".env"
if (Test-Path $EnvFile) {
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^\s*DB_USER=(.*)$') { $DbUser = $Matches[1].Trim() }
        if ($_ -match '^\s*DB_NAME=(.*)$') { $DbName = $Matches[1].Trim() }
    }
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Dest = Join-Path $Root "backups\$Stamp"
New-Item -ItemType Directory -Force -Path $Dest | Out-Null

$Dump = Join-Path $Dest "postgres.sql"
cmd /c "docker compose exec -T postgres pg_dump -U $DbUser -d $DbName --clean --if-exists > `"$Dump`""
if ($LASTEXITCODE -ne 0) { throw "pg_dump a échoué ($LASTEXITCODE)" }

$Container = (docker compose ps -q alfresco).Trim()
if (-not $Container) { throw "Le conteneur alfresco n'est pas démarré." }
docker run --rm --volumes-from $Container -v "${Dest}:/backup" alpine:3.22 tar czf /backup/alfresco-content.tgz -C /usr/local/tomcat/alf_data .
if ($LASTEXITCODE -ne 0) { throw "L'archive du contenu a échoué ($LASTEXITCODE)" }

Write-Output "Sauvegarde écrite dans $Dest"
