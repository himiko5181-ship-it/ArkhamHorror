# 아컴 호러 카드게임 한국어판 설치/업데이트 (Windows)
# PowerShell에서:  irm https://raw.githubusercontent.com/himiko5181-ship-it/ArkhamHorror/main/install-ko.ps1 | iex
# 같은 명령을 다시 실행하면 최신 버전으로 업데이트됩니다. (DB와 config\ 는 그대로 유지)
$ErrorActionPreference = 'Stop'
$Repo = 'himiko5181-ship-it/ArkhamHorror'
$Dir = if ($env:ARKHAM_INSTALL_DIR) { $env:ARKHAM_INSTALL_DIR } else { Join-Path $HOME 'arkham-horror-ko' }
function Say($m) { Write-Host "==> $m" -ForegroundColor Green }
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker가 없습니다. https://www.docker.com/ 에서 Docker Desktop을 설치하세요.' }
docker info *> $null; if ($LASTEXITCODE -ne 0) { throw 'Docker가 실행 중이 아닙니다. Docker Desktop을 켜고 다시 실행하세요.' }
New-Item -ItemType Directory -Force -Path $Dir | Out-Null
Say "최신 코드 내려받는 중 ($Repo)"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("arkham-ko-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
$zip = Join-Path $tmp 'src.zip'
Invoke-WebRequest -UseBasicParsing "https://codeload.github.com/$Repo/zip/refs/heads/main" -OutFile $zip
Expand-Archive -Path $zip -DestinationPath $tmp -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
Copy-Item -Path (Join-Path $src.FullName '*') -Destination $Dir -Recurse -Force
Remove-Item $tmp -Recurse -Force
Set-Location $Dir
New-Item -ItemType Directory -Force -Path config | Out-Null
$pw = Join-Path $Dir 'config\postgres_password.txt'
if (Test-Path $pw -PathType Container) { Remove-Item $pw -Recurse -Force }
if (-not (Test-Path $pw) -or (Get-Item $pw).Length -eq 0) {
  Say 'DB 비밀번호 생성'
  $b = New-Object byte[] 32; [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  [IO.File]::WriteAllText($pw, (($b | ForEach-Object { $_.ToString('x2') }) -join '') + "`n")
}
$f = @('-f', 'docker-compose.yml', '-f', 'docker-compose.ko.yml')
Say '원본 서버 이미지 받는 중'; docker pull halogenandtoast/arkham-horror:latest
Say '한국어 프런트엔드 빌드 중 (처음엔 몇 분 걸려요)'; docker compose @f build web
if ($LASTEXITCODE -ne 0) { throw '빌드 실패' }
Say '실행'; docker compose @f up -d
Write-Host ''
Write-Host '설치 완료!  http://localhost:3000  (로그인 후 설정에서 언어를 한국어로)'
Write-Host "끄기: cd `"$Dir`"; docker compose -f docker-compose.yml -f docker-compose.ko.yml down"
