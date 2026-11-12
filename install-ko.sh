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
