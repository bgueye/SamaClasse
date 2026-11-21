# Génère la requête d'écriture des indices d'un dossier de brouillons.
# Les espaces insécables deviennent le repère ~NB~ (remplacé par chr(160)
# dans la base) : elles ne se voient pas et se perdraient à la recopie.
#
# -Controle : génère à la place une requête en lecture seule qui signale
# les exercices d'une autre leçon, les exercices oubliés, et les indices
# qui contiennent une réponse attendue (feuilles de `reponse`, texte du bon
# choix d'un QCM). Certains signalements sont sans gravité (un indice qui
# cite les deux choix « qui » et « que ») : les relire un par un.
param([string]$Dossier, [string]$Sortie, [int[]]$Lecons, [switch]$Controle)

$nb = [string][char]0x00A0
$speciaux = -join ([char[]](0x00AB, 0x00BB, 0x2019, 0x2026, 0x2212, 0x2014, 0x2013, 0x00B0, 0x00B2, 0x00B3, 0x0152, 0x0153))
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
if ($Controle) {
  $sql = "with indices(lecon_id, id, texte) as (values`n" + ($lignes -join ",`n") + "`n),`n" + @'
attendues as (
  select x.id, lower(v #>> '{}') as attendue
  from public.exercices x, jsonb_path_query(x.reponse, 'strict $.**') as v
  where jsonb_typeof(v) in ('string', 'number')
  union
  select x.id, lower(x.donnees->'questions'->(i::int - 1)->'choix'->>(r #>> '{}')::int)
  from public.exercices x, jsonb_array_elements(x.reponse) with ordinality as t(r, i)
  where x.type = 'qcm'
)
select 'mauvaise leçon' as probleme, i.id::text as exercice, null as detail
from indices i left join public.exercices x on x.id = i.id
where x.lecon_id is distinct from i.lecon_id
union all
select 'réponse dans l''indice', i.id::text, a.attendue
from indices i join attendues a on a.id = i.id
where char_length(a.attendue) >= 3 and position(a.attendue in lower(replace(i.texte, '~NB~', ' '))) > 0
union all
select 'exercice sans indice', x.id::text, null
from public.exercices x
where x.lecon_id in (select distinct lecon_id from indices) and x.id not in (select id from indices)
order by 1, 2;
'@
} else {
  $sql = "update public.exercices x set indice = replace(v.indice, '~NB~', chr(160))`nfrom (values`n" +
    ($lignes -join ",`n") +
    "`n) as v(lecon_id, id, indice)`nwhere x.id = v.id and x.lecon_id = v.lecon_id and x.indice is null`nreturning x.id;"
}
Set-Content $Sortie $sql -Encoding utf8
Write-Output "$($lignes.Count) indices, $total espaces insécables"
