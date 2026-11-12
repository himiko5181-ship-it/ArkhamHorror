#!/usr/bin/env bash
# 아컴 호러 카드게임 한국어판 설치/업데이트 (macOS·Linux)
#   curl -fsSL https://raw.githubusercontent.com/himiko5181-ship-it/ArkhamHorror/main/install-ko.sh | bash
# 같은 명령을 다시 실행하면 최신 버전으로 업데이트됩니다. (DB와 config/ 는 그대로 유지)
set -euo pipefail
REPO="himiko5181-ship-it/ArkhamHorror"
DIR="${ARKHAM_INSTALL_DIR:-arkham-horror-ko}"
say(){ printf '\033[0;32m==> %s\033[0m\n' "$*"; }
die(){ printf '\033[0;31m오류: %s\033[0m\n' "$*" >&2; exit 1; }
command -v docker >/dev/null || die "Docker가 없습니다. https://www.docker.com/ 에서 설치하세요."
docker info >/dev/null 2>&1 || die "Docker가 실행 중이 아닙니다. Docker Desktop을 켜고 다시 실행하세요."
mkdir -p "$DIR"; cd "$DIR"
say "최신 코드 내려받는 중 ($REPO)"
tmp="$(mktemp -d)"
curl -fsSL "https://codeload.github.com/$REPO/tar.gz/refs/heads/main" | tar -xz -C "$tmp"
src="$(ls -d "$tmp"/*/)"
# 기존 config/, 받아 둔 이미지(frontend/public/img)는 보존
( cd "$src" && tar -cf - --exclude='./frontend/public/img/arkham/*/cards' . ) | tar -xf -
rm -rf "$tmp"

# 한국어 카드 이미지 (GitHub 릴리스에서 받음; 이미 같은 버전이면 건너뜀)
# ARKHAM_SKIP_KO_CARDS=1 이면 건너뜀 (그 경우 카드는 영어 이미지로 표시)
KO_TAG="ko-cards-v1"
KO_ROOT="frontend/public/img/arkham/ko"
KO_MARK="$KO_ROOT/cards/.version"
if [ "${ARKHAM_SKIP_KO_CARDS:-}" = "1" ]; then
  say "한국어 카드 이미지 건너뜀 (ARKHAM_SKIP_KO_CARDS=1)"
elif [ -f "$KO_MARK" ] && [ "$(tr -d ' \r\n' < "$KO_MARK")" = "$KO_TAG" ]; then
  say "한국어 카드 이미지 최신 ($KO_TAG)"
else
  command -v unzip >/dev/null || die "unzip이 필요합니다. (예: sudo apt install unzip)"
  say "한국어 카드 이미지 내려받는 중 ($KO_TAG, 약 540MB)"
  mkdir -p "$KO_ROOT"
  kt="$(mktemp -d)"
  ok=1
  for p in ko-cards-1.zip ko-cards-2.zip; do
    echo "    $p"
    # zip 안은 cards/xxxx.avif 구조
    if ! { curl -fL --retry 3 -o "$kt/$p" "https://github.com/$REPO/releases/download/$KO_TAG/$p" && unzip -oq "$kt/$p" -d "$KO_ROOT"; }; then
      ok=0; break
    fi
    rm -f "$kt/$p"
  done
  rm -rf "$kt"
  if [ "$ok" = 1 ]; then
    printf '%s' "$KO_TAG" > "$KO_MARK"
    say "한국어 카드 이미지 $(ls "$KO_ROOT/cards" | grep -c '\.avif$') 장 설치됨"
  else
    # 이미지가 없어도 게임은 됨 (카드만 영어로 표시). 다음 실행 때 다시 시도.
    printf '\033[0;33m경고: 한국어 카드 이미지를 받지 못했습니다. 카드는 영어로 표시됩니다. 다시 실행하면 재시도합니다.\033[0m\n' >&2
  fi
fi

mkdir -p config
[ -d config/postgres_password.txt ] && rmdir config/postgres_password.txt
if [ ! -s config/postgres_password.txt ]; then
  say "DB 비밀번호 생성"; head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n' > config/postgres_password.txt; echo >> config/postgres_password.txt
fi
C="docker compose -f docker-compose.yml -f docker-compose.ko.yml"
say "원본 서버 이미지 받는 중"; docker pull halogenandtoast/arkham-horror:latest
say "한국어 프런트엔드 빌드 중 (처음엔 몇 분 걸려요)"; $C build web
say "실행"; $C up -d
echo; echo "설치 완료!  http://localhost:3000  (로그인 후 설정에서 언어를 한국어로)"
echo "끄기: cd $DIR && $C down"
