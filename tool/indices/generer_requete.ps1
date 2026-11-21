# Génère la requête d'écriture des indices d'un dossier de brouillons.
# Les espaces insécables deviennent le repère ~NB~ (remplacé par chr(160)
# dans la base) : elles ne se voient pas et se perdraient à la recopie.
param([string]$Dossier, [string]$Sortie, [int[]]$Lecons)

$nb = [string][char]0x00A0
$speciaux = -join ([char[]](0x00AB, 0x00BB, 0x2019, 0x2026, 0x2212, 0x2014, 0x2013, 0x00B0, 0x0152, 0x0153))
$autorises = '^[\x20-\x7E\xC0-\xFF' + [regex]::Escape($speciaux) + ']*$'
$lignes = @()
$total = 0
foreach ($f in Get-ChildItem $Dossier -Filter 'lecon_*.json') {
  $l = [int]($f.BaseName -replace 'lecon_', '')
  if ($Lecons -and ($Lecons -notcontains $l)) { continue }
  $o = Get-Content $f.FullName -Raw -Encoding utf8 | ConvertFrom-Json
  foreach ($p in $o.PSObject.Properties) {
    $total += ([regex]::Matches($p.Value, $nb)).Count
    $t = $p.Value.Replace($nb, '~NB~')
    if ($t.Contains('$i$')) { throw "délimiteur dans l'exercice $($p.Name)" }
    if ($t -notmatch $autorises) { Write-Output "ATTENTION exercice $($p.Name) : caractère inattendu" }
    $lignes += "  ($l, $($p.Name), `$i`$$t`$i`$)"
  }
}
$sql = "update public.exercices x set indice = replace(v.indice, '~NB~', chr(160))`nfrom (values`n" +
  ($lignes -join ",`n") +
  "`n) as v(lecon_id, id, indice)`nwhere x.id = v.id and x.lecon_id = v.lecon_id and x.indice is null`nreturning x.id;"
Set-Content $Sortie $sql -Encoding utf8
Write-Output "$($lignes.Count) indices, $total espaces insécables"
