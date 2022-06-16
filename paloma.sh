#!/bin/bash

while true
do

# Logo

echo -e '\e[40m\e[91m'
echo -e '  ____                  _                    '
echo -e ' / ___|_ __ _   _ _ __ | |_ ___  _ __        '
echo -e '| |   |  __| | | |  _ \| __/ _ \|  _ \       '
echo -e '| |___| |  | |_| | |_) | || (_) | | | |      '
echo -e ' \____|_|   \__  |  __/ \__\___/|_| |_|      '
echo -e '            |___/|_|                         '
echo -e '    _                 _                      '
echo -e '   / \   ___ __ _  __| | ___ _ __ ___  _   _ '
echo -e '  / _ \ / __/ _  |/ _  |/ _ \  _   _ \| | | |'
echo -e ' / ___ \ (_| (_| | (_| |  __/ | | | | | |_| |'
echo -e '/_/   \_\___\__ _|\__ _|\___|_| |_| |_|\__  |'
echo -e '                                       |___/ '
echo -e '\e[0m'

sleep 2

# Menu

PS3='Select an action: '
options=(
"Install"
"Create Wallet"
"Create Validator"
"Exit")
select opt in "${options[@]}"
do
case $opt in

"Install")
echo "============================================================"
echo "Install start"
echo "============================================================"


# set vars
if [ ! $NODENAME ]; then
	read -p "Enter node name: " NODENAME
	echo 'export NODENAME='$NODENAME >> $HOME/.bash_profile
fi
echo "export WALLET=wallet" >> $HOME/.bash_profile
echo "export CHAIN_ID=paloma" >> $HOME/.bash_profile
source $HOME/.bash_profile

# update
sudo apt update && sudo apt upgrade -y


# packages
sudo apt install curl build-essential git wget jq make gcc tmux -y

# install go
source $HOME/.bash_profile
    if go version > /dev/null 2>&1
    then
        echo -e '\n\e[40m\e[92mSkipped Go installation\e[0m'
    else
        echo -e '\n\e[40m\e[92mStarting Go installation...\e[0m'
        ver="1.18.1"
cd $HOME
wget "https://golang.org/dl/go$ver.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf "go$ver.linux-amd64.tar.gz"
rm "go$ver.linux-amd64.tar.gz"
echo "export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin" >> ~/.bash_profile
source ~/.bash_profile
go version
    fi

# download binary
wget -qO - https://github.com/palomachain/paloma/releases/download/v0.1.0-alpha/paloma_0.1.0-alpha_Linux_x86_64v3.tar.gz | \
sudo tar -C /usr/local/bin -xvzf - palomad
sudo chmod +x /usr/local/bin/palomad
sudo wget -P /usr/lib https://github.com/CosmWasm/wasmvm/raw/main/api/libwasmvm.x86_64.so

# config
palomad config chain-id $CHAIN_ID
palomad config keyring-backend test

# init
palomad init $NODENAME --chain-id $CHAIN_ID

# download genesis and addrbook
wget -qO $HOME/.paloma/config/genesis.json "https://raw.githubusercontent.com/palomachain/testnet/master/livia/genesis.json"
wget -qO $HOME/.paloma/config/addrbook.json "https://raw.githubusercontent.com/palomachain/testnet/master/livia/addrbook.json"

# set minimum gas price
sed -i -e "s/^minimum-gas-prices *=.*/minimum-gas-prices = \"0grain\"/" $HOME/.paloma/config/app.toml

# set peers and seeds
SEEDS=""
PEERS="223e39487e0e363833f19ead57c3bb98303730f9@116.202.112.175:26601,2e0623d133e8da778e379b01ea0b8cb477f5b346@135.181.116.109:38456,61db8ce4cf4e9c0cbbb9bfb4c90ae6d02c17d6bd@138.201.139.175:20456,eed0ef9a854fd601401d5484d64cb3e0b02a955b@144.126.135.27:46656,5cea05a8c5dffacd0ce022e1726734a0d8cbfdca@62.141.39.178:26656,1003cf3b68ddfd3a55bb20f5c6041c1efe2e52eb@65.21.143.79:21556,d8d619448fef295ac11463b834b4a169dbf8f9ba@135.181.47.192:26656,ebeca6a40fba2c3a3aa5a9c99d9222163bd6d4c6@95.216.154.164:26656,927cc47316c0530b54a711e601b14a1fb24c0153@62.171.128.66:26656"
sed -i -e "s/^seeds *=.*/seeds = \"$SEEDS\"/; s/^persistent_peers *=.*/persistent_peers = \"$PEERS\"/" $HOME/.paloma/config/config.toml

#index
indexer="null"
sed -i -e "s/^indexer *=.*/indexer = \"$indexer\"/" $HOME/.paloma/config/config.toml

# enable prometheus
sed -i -e "s/prometheus = false/prometheus = true/" $HOME/.paloma/config/config.toml

# config pruning
pruning="custom"
pruning_keep_recent="100"
pruning_keep_every="0"
pruning_interval="50"
sed -i -e "s/^pruning *=.*/pruning = \"$pruning\"/" $HOME/.paloma/config/app.toml
sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"$pruning_keep_recent\"/" $HOME/.paloma/config/app.toml
sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"$pruning_keep_every\"/" $HOME/.paloma/config/app.toml
sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"$pruning_interval\"/" $HOME/.paloma/config/app.toml

# reset
palomad tendermint unsafe-reset-all


# create service
sudo tee /etc/systemd/system/palomad.service > /dev/null <<EOF
[Unit]
Description=paloma
After=network-online.target
[Service]
User=$USER
ExecStart=$(which palomad) start
Restart=on-failure
RestartSec=3
LimitNOFILE=65535
[Install]
WantedBy=multi-user.target
EOF

# start service
sudo systemctl daemon-reload
sudo systemctl enable palomad
sudo systemctl restart palomad

break
;;

"Create Wallet")
palomad keys add $WALLET
echo "============================================================"
echo "Save address and mnemonic"
echo "============================================================"
WALLET_ADDRESS=$(palomad keys show $WALLET -a)
VALOPER_ADDRESS=$(palomad keys show $WALLET --bech val -a)
echo 'export WALLET_ADDRESS='${WALLET_ADDRESS} >> $HOME/.bash_profile
echo 'export VALOPER_ADDRESS='${VALOPER_ADDRESS} >> $HOME/.bash_profile
source $HOME/.bash_profile

break
;;


"Create Validator")
palomad tx staking create-validator \
  --amount 100000000grain \
  --from $WALLET \
  --commission-max-change-rate "0.01" \
  --commission-max-rate "0.2" \
  --commission-rate "0.07" \
  --min-self-delegation "1" \
  --pubkey  $(palomad tendermint show-validator) \
  --moniker $NODENAME \
  --chain-id $CHAIN_ID
  
break
;;

"Exit")
exit
;;
*) echo "invalid option $REPLY";;
esac
done
done
