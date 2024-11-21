#!/bin/bash

# 색깔 변수 정의
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[36m'
NC='\033[0m' # No Color
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
WHITE='\033[1;37m'
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_BLUE='\033[44m'

echo -e "\n${BG_GREEN}${WHITE}=== zkverify 노드 설치 및 설정 스크립트 시작 ===${NC}\n"

# 필수패키지 설치
sudo apt update && sudo apt upgrade -y 
sudo apt install -y jq
sudo apt install -y curl git jq lz4 build-essential unzip

# 작업 공간 경로 설정
WORK="/root/compose-zkverify-simplified"

# 기존 작업 공간이 존재하면 자동으로 삭제
if [ -d "$WORK" ]; then
    echo "기존 작업 공간을 삭제합니다: $WORK"
    rm -rf "$WORK"
fi

# Docker 설치 확인
if ! command -v docker &> /dev/null; then
    echo -e "${BG_RED}${WHITE}Docker가 설치되어 있지 않습니다. Docker CE 설치를 진행합니다...${NC}"
    
    # 필요한 패키지 설치
    sudo apt update
    sudo apt install -y ca-certificates curl gnupg lsb-release
    
    # Docker의 공식 GPG 키 추가
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
    
    # Docker 저장소 추가
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Docker CE 설치
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    
    # 현재 사용자를 docker 그룹에 추가
    sudo usermod -aG docker $USER
    newgrp docker
    
    echo -e "${BG_GREEN}${WHITE}Docker CE 설치가 완료되었습니다! ✨${NC}"
else
    echo -e "${GREEN}Docker가 이미 설치되어 있습니다.${NC}"
fi

# Docker Compose 설치 확인
if ! command -v docker-compose &> /dev/null; then
    echo -e "${RED}Docker Compose가 설치되어 있지 않습니다. 설치를 진행합니다...${NC}"
    # 최신 Docker Compose 설치
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}Docker Compose 설치가 완료되었습니다.${NC}"
else
    echo -e "${GREEN}Docker Compose가 이미 설치되어 있습니다.${NC}"
fi

# 사용자에게 버전 입력 요청
echo -e "\n${PURPLE}┌────────────────────────────────────────┐${NC}"
echo -e "${PURPLE}│${NC} ${CYAN}최신 버전 확인:${NC}                        ${PURPLE}│${NC}"
echo -e "${PURPLE}│${NC} ${GREEN}https://github.com/zkVerify/compose-zkverify-simplified/releases${NC} ${PURPLE}│${NC}"
echo -e "${PURPLE}└────────────────────────────────────────┘${NC}\n"
echo -e "위 링크에서 최신 버전을 확인하고 입력해주세요. (예: 0.6.0)"
read -p "버전을 입력하세요: " VERSION

# 입력받은 버전으로 클론
git clone --branch $VERSION https://github.com/HorizenLabs/compose-zkverify-simplified.git

cd "$WORK"
chmod +x scripts/init.sh
scripts/init.sh

cat /$WORK/deployments/validator-node/testnet/configs/node/secrets/secret_phrase.dat
echo -e "${GREEN}위에나온 지갑정보를 저장해주세요. 폴카닷월렛입니다.${NC}"
echo -e "${GREEN}Faucet을 받아주세요:https://www.zkay.io/faucet${NC}"

docker compose up -d

echo -e "${GREEN}검증자 블록체인 등록을 시작합니다.${NC}"

echo -e "\n${BG_BLUE}${WHITE} STEP 1 ${NC} ${CYAN}Babe 및 ImOnline 키 생성 중...${NC}"
echo -e "비밀 구문을 입력하라는 메시지가 표시되면 이전 단계의 비밀 구문을 똑같이 입력하세요."
bash docker run --rm -ti --entrypoint zkv-node horizenlabs/zkverify:latest key inspect --scheme sr25519
echo -e "\n${GREEN}위의 출력에서 Public key (hex)를 저장해두세요. 이것이 Babe와 ImOnline 키입니다.${NC}"
read -q "위 단계들을 완료하셨다면 아무 키나 누르세요."

echo -e "\n${BG_BLUE}${WHITE} STEP 2 ${NC} ${CYAN}Grandpa 키 생성 중...${NC}"
echo -e "다시 한 번 같은 비밀 구문을 입력하세요."
bash docker run --rm -ti --entrypoint zkv-node horizenlabs/zkverify:latest key inspect --scheme ed25519
echo -e "\n${GREEN}위의 출력에서 Public key (hex)를 저장해두세요. 이것이 Grandpa 키입니다.${NC}"
read -q "위 단계들을 완료하셨다면 아무 키나 누르세요."

echo -e "1. 위에서 생성된 세 개의 키(Babe, Grandpa, ImOnline)를 하나의 문자열로 연결하세요."
echo -e "예)Babe,Imonline:0x123, Granpa:0x456이라면 : 0x123456123"
echo -e "2. https://polkadot.js.org/apps/?rpc=wss%3A%2F%2Ftestnet-rpc.zkverify.io#/explorer 에 접속하세요."
echo -e "3. 개발자 > 익스트런식 메뉴로 이동하세요."
echo -e "4. session과 setKeys를 선택하세요."
echo -e "5. 1번에서 연결한 문자열을 keys: NhRuntimeSessionKeys 란에 붙여넣으세요."
echo -e "6. proof 필드는 비워두세요."
echo -e "7. 거래를 제출합니다 버튼을 클릭하여 트랜잭션을 제출하세요."
read -q "위 단계들을 완료하셨다면 아무 키나 누르세요."

echo -e "${GREEN}토큰 스테이킹을 시작합니다.${NC}"
echo -e "1. 개발자 > 익스트런식 메뉴로 이동하세요."
echo -e "2. staking과 bond를 선택하세요."
echo -e "3. 최대한 많은 양의 토큰을 입력하세요."
echo -e "4. 거래를 제출합니다 버튼을 클릭하여 트랜잭션을 제출하세요."
read -q "위 단계들을 완료하셨다면 아무 키나 누르세요."

echo -e "${GREEN}검증자 증명.${NC}"
echo -e "1. 개발자 > 익스트런식 메뉴로 이동하세요."
echo -e "2. staking과 validator를 선택하세요."
echo -e "3. 커미션은 100000000으로 설정하고 Blocked는 아니오로 설정하세요."
echo -e "4. 거래를 제출합니다 버튼을 클릭하여 트랜잭션을 제출하세요."
echo -e "5. 네트워크 > 스테이킹 메뉴로 이동해서 웨이팅 탭에 본인 주소가 있는지 확인하세요"
read -q "위 단계들을 완료하셨다면 아무 키나 누르세요."

echo -e "${BG_GREEN}${WHITE}🎉 zkverify 노드 설치 및 설정이 완료되었습니다! 🎉${NC}"
echo -e "${BLUE}스크립트작성자: https://t.me/kjkresearch${NC}"