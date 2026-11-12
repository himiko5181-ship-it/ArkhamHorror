# 아컴 호러 카드게임 한국어판 설치/업데이트 (Windows)
# PowerShell에서:  irm https://raw.githubusercontent.com/himiko5181-ship-it/ArkhamHorror/main/install-ko.ps1 | iex
# 같은 명령을 다시 실행하면 최신 버전으로 업데이트됩니다. (DB와 config\ 는 그대로 유지)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'  # PS 5.1 진행바는 Invoke-WebRequest 다운로드를 매우 느리게 함
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
if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
  tar.exe -xf $zip -C $tmp   # Expand-Archive보다 훨씬 빠름 (Windows 10 1803+ 기본 포함)
  if ($LASTEXITCODE -ne 0) { throw '소스 압축 풀기 실패' }
} else {
  Expand-Archive -Path $zip -DestinationPath $tmp -Force
}
Remove-Item $zip -Force
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
Copy-Item -Path (Join-Path $src.FullName '*') -Destination $Dir -Recurse -Force
Remove-Item $tmp -Recurse -Force
Set-Location $Dir

# 한국어 카드 이미지 (GitHub 릴리스에서 받음; 이미 같은 버전이면 건너뜀)
# ARKHAM_SKIP_KO_CARDS=1 이면 건너뜀 (그 경우 카드는 영어 이미지로 표시)
$KoTag = 'ko-cards-v1'
$KoParts = @('ko-cards-1.zip', 'ko-cards-2.zip')
$KoRoot = Join-Path $Dir 'frontend\public\img\arkham\ko'
$KoMark = Join-Path $KoRoot 'cards\.version'
if ($env:ARKHAM_SKIP_KO_CARDS -eq '1') {
  Say '한국어 카드 이미지 건너뜀 (ARKHAM_SKIP_KO_CARDS=1)'
} elseif ((Test-Path $KoMark) -and ((Get-Content $KoMark -Raw).Trim() -eq $KoTag)) {
  Say "한국어 카드 이미지 최신 ($KoTag)"
} else {
  Say "한국어 카드 이미지 내려받는 중 ($KoTag, 약 540MB)"
  New-Item -ItemType Directory -Force -Path $KoRoot | Out-Null
  $kt = Join-Path ([IO.Path]::GetTempPath()) ("arkham-ko-cards-" + [guid]::NewGuid())
  New-Item -ItemType Directory -Path $kt | Out-Null
  $oldPP = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'  # PS 5.1 진행바는 다운로드를 매우 느리게 함
  try {
    foreach ($p in $KoParts) {
      Write-Host "    $p"
      $out = Join-Path $kt $p
      Invoke-WebRequest -UseBasicParsing "https://github.com/$Repo/releases/download/$KoTag/$p" -OutFile $out
      # zip 안은 cards/xxxx.avif 구조
      if (Get-Command tar.exe -ErrorAction SilentlyContinue) {
        tar.exe -xf $out -C $KoRoot
        if ($LASTEXITCODE -ne 0) { throw "$p 압축 풀기 실패" }
      } else {
        Expand-Archive -Path $out -DestinationPath $KoRoot -Force
      }
      Remove-Item $out -Force
    }
    [IO.File]::WriteAllText($KoMark, $KoTag)
    $n = (Get-ChildItem (Join-Path $KoRoot 'cards') -Filter *.avif).Count
    Say "한국어 카드 이미지 $n 장 설치됨"
  } catch {
    # 이미지가 없어도 게임은 됨 (카드만 영어로 표시). 다음 실행 때 다시 시도.
    Write-Warning "한국어 카드 이미지를 받지 못했습니다: $($_.Exception.Message)"
    Write-Warning '카드는 영어 이미지로 표시됩니다. 나중에 같은 명령을 다시 실행하면 다시 시도합니다.'
  } finally {
    $ProgressPreference = $oldPP
    Remove-Item $kt -Recurse -Force -ErrorAction SilentlyContinue
  }
}

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
