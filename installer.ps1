# SamaClasse : installation du projet Flutter sous Windows.
#
# À lancer une seule fois, depuis le dossier du projet :
#   cd C:\Dev\projets\SamaClasse
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1
#
# Ce script :
#   1. génère les dossiers de plateforme (android, ios, web) avec `flutter create`,
#      sans toucher aux fichiers déjà présents (lib, test, pubspec.yaml…) ;
#   2. ajoute la permission Internet à l'application Android (sinon la version
#      publiée ne peut pas joindre Supabase) et la nomme « SamaClasse » ;
#   3. télécharge les paquets et lance les tests.

$ErrorActionPreference = 'Stop'
Set-Location -Path $PSScriptRoot

Write-Host '== Version de Flutter' -ForegroundColor Cyan
flutter --version
if ($LASTEXITCODE -ne 0) { throw 'Flutter est introuvable : ajoute flutter\bin au PATH.' }

Write-Host '== Création des dossiers android, ios et web' -ForegroundColor Cyan
flutter create . --project-name samaclasse --org sn.samaclasse --platforms android,ios,web --no-pub
if ($LASTEXITCODE -ne 0) { throw 'flutter create a échoué.' }

$manifeste = Join-Path $PSScriptRoot 'android\app\src\main\AndroidManifest.xml'
if (Test-Path $manifeste) {
  Write-Host '== Réglage du manifeste Android' -ForegroundColor Cyan
  $xml = [System.IO.File]::ReadAllText($manifeste)
  if ($xml -notmatch 'android\.permission\.INTERNET') {
    $xml = $xml -replace '(\s*)<application', "`$1<uses-permission android:name=`"android.permission.INTERNET`" />`$1<application"
  }
  # flutter_tts (« Écouter la leçon ») : sans cette requête, Android 11+
  # ne laisse pas l'application trouver le moteur de synthèse vocale.
  if ($xml -notmatch 'android\.intent\.action\.TTS_SERVICE') {
    $requeteTts = '<intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>'
    if ($xml -match '</queries>') {
      $xml = $xml -replace '</queries>', "    $requeteTts`n    </queries>"
    } else {
      $xml = $xml -replace '</manifest>', "    <queries>`n        $requeteTts`n    </queries>`n</manifest>"
    }
  }
  $xml = $xml -replace 'android:label="samaclasse"', 'android:label="SamaClasse"'
  [System.IO.File]::WriteAllText($manifeste, $xml)
}

$indexWeb = Join-Path $PSScriptRoot 'web\index.html'
if (Test-Path $indexWeb) {
  $html = [System.IO.File]::ReadAllText($indexWeb)
  $html = $html -replace '<title>samaclasse</title>', '<title>SamaClasse</title>'
  $html = $html -replace '<html>', '<html lang="fr">'
  [System.IO.File]::WriteAllText($indexWeb, $html)
}

Write-Host '== Téléchargement des paquets' -ForegroundColor Cyan
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get a échoué.' }

Write-Host '== Analyse du code' -ForegroundColor Cyan
flutter analyze

Write-Host '== Tests' -ForegroundColor Cyan
flutter test

Write-Host ''
Write-Host 'Terminé. Pour lancer l''application :' -ForegroundColor Green
Write-Host '  flutter run --dart-define-from-file=config/supabase.json'
Write-Host 'ou, dans VS Code : Exécuter > SamaClasse (F5).'
