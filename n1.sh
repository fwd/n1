#!/bin/bash

#################################
## N1: Nano Command Line Tool  ##
## (c) 2018-3001 @nano2dev     ##
## Released under MIT License  ##
#################################

# Install 'jq' if needed.
if ! command -v jq &> /dev/null; then
	if [  -n "$(uname -a | grep Ubuntu)" ]; then
		sudo apt install jq -y
	else
		echo "${CYAN}Cloud${NC}: We could not auto install 'jq'. Please install it manually, before continuing."
		exit 1
	fi
fi

# Install 'curl' if needed.
if ! command -v curl &> /dev/null; then
	# Really?! What kind of rinky-dink machine is this?
	if [  -n "$(uname -a | grep Ubuntu)" ]; then
		sudo apt install curl -y
	else
		echo "${CYAN}Cloud${NC}: We could not auto install 'curl'. Please install it manually, before continuing."
		exit 1
	fi
fi

# VERSION: 0.4-C
# CODENAME: "GOOSE"
VERSION=0.5-D
GREEN=$'\e[0;32m'
BLUE=$'\e[0;34m'
CYAN=$'\e[1;36m'
RED=$'\e[0;31m'
NC=$'\e[0m'

GREEN2=$'\e[1;92m'

# GET HOME DIR
DIR=$(eval echo "~$different_user")

LOCAL_DOCS=$(cat <<EOF
Usage
⏺  $ n2 setup node
⏺  $ n2 balance --local
⏺  $ n2 whois @moon
⏺  $ n2 account @kraken --json
⏺  $ n2 send @esteban 0.1
⏺  $ n2 qrcode @fosse
⏺  $ n2 plugin --list
EOF
)

OPTIONS_DOCS=$(cat <<EOF
Options
--help, -h  Print CLI Documentation.
--update, -u  Update CLI Script.
--version, -v  Print CLI Version.
--uninstall, -u  Remove N1 CLI.
EOF
)

DOCS=$(cat <<EOF
$LOCAL_DOCS

$OPTIONS_DOCS
EOF
)

if [[ $1 == "" ]] || [[ $1 == "help" ]] || [[ $1 == "list" ]] || [[ $1 == "--help" ]]; then
	cat <<EOF
$DOCS
EOF
	exit 1
fi

if [[ "$1" = "--json" ]]; then
	echo "Tip: Use the '--json' flag to get command responses in JSON."
	exit 1
fi



function local_send() {

	if curl -s --fail -X POST '[::1]:7076'; then
		echo ""
	else
	   echo "${CYAN}Cloud${NC}: No local Node found. Use 'n2 setup node' or use 'n2 cloud send'"
	   exit 1
	fi;

	if [[ $2 == "" ]]; then
		echo "${CYAN}Cloud${NC}: Missing Username or Nano Address."
		exit 1
	fi
	
	if [[ $3 == "" ]]; then
		echo "${CYAN}Cloud${NC}: Missing amount. Use 'all' to send balance."
		exit 1
	fi

	WALLET_ID=$(docker exec -it nano-node /usr/bin/nano_node --wallet_list | grep 'Wallet ID' | awk '{ print $NF}' | tr -d '[:space:]' )

	UUID=$(cat /proc/sys/kernel/random/uuid)

	AMOUNT_IN_RAW=$(curl -s "https://nano.to/cloud/convert/toRaw/$3" \
		-H "Accept: application/json" \
		-H "session: $(cat $DIR/.n2-session)" \
		-H "Content-Type:application/json" \
		--request GET)

	SRC=""
	DEST=""

	ACCOUNT=$(curl -s "https://nano.to/$SRC/account" \
	-H "Accept: application/json" \
	-H "Content-Type:application/json" \
	--request GET)

	POW=$(curl -s "https://nano.to/$(jq -r '.frontier' <<< "$ACCOUNT")/pow" \
	-H "Accept: application/json" \
	-H "Content-Type:application/json" \
	--request GET)

	if [[ $(jq -r '.error' <<< "$POW") == "429" ]]; then
		echo
		echo "==============================="
		echo "       USED ALL CREDITS        "
		echo "==============================="
		echo "  Use 'n2 buy pow' or wait.    "
		echo "==============================="
		echo
		return
	fi

	WORK=$(jq -r '.work' <<< "$POW")

	SEND_ATTEMPT=$(curl -s '[::1]:7076' \
	-H "Accept: application/json" \
	-H "Content-Type:application/json" \
	--request POST \
	--data @<(cat <<EOF
{
	"action": "send",
	"wallet": "$WALLET_ID",
	"source": "$SRC",
	"destination": "$DEST",
	"amount": "$(jq -r '.value' <<< "$AMOUNT_IN_RAW")",
	"id": "$UUID",
	"json_block": "true",
	"work": "$WORK"
}
EOF
	))

	if [[ $(jq -r '.block' <<< "$SEND_ATTEMPT") == "" ]]; then
		echo
		echo "================================"
		echo "             ERROR              "
		echo "================================"
		echo "$(jq -r '.error' <<< "$SEND_ATTEMPT") "
		echo "================================"
		echo
		exit 1
	fi

	echo "==============================="
	echo "         NANO RECEIPT          "
	echo "==============================="
	echo "AMOUNT: "$3
	echo "TO: "$DEST
	echo "FROM: "$SRC
	echo "BLOCK: "$(jq -r '.block' <<< "$SEND_ATTEMPT")
	echo "--------------------------------"
	echo "BROWSER: https://nanolooker.com/block/$(jq -r '.block' <<< "$SEND_ATTEMPT")"
	echo "==============================="

	exit 1
	
}


if [[ "$1" = "rpc" ]] || [[ "$1" = "--rpc" ]] || [[ "$1" = "curl" ]] || [[ "$1" = "--curl" ]] ; then

	curl -s "[::1]:7076" \
	-H "Accept: application/json" \
	-H "Content-Type:application/json" \
	--request POST \
	--data @<(cat <<EOF
{ "action": "$2", "json_block": "true" }
EOF
) | jq

	exit 1
fi

if [[ "$2" = "exec" ]] || [[ "$2" = "--exec" ]]; then
	docker exec -it nano-node /usr/bin/nano_node $1 $2 $3 $4
	exit 1
fi

if [[ "$1" = "node" ]] && [[ "$2" = "--wallet" ]]; then
	docker exec -it nano-node /usr/bin/nano_node --wallet_list | grep 'Wallet ID' | awk '{ print $NF}'
fi

# if [[ "$1" = "--seed" ]] || [[ "$1" = "--secret" ]]; then
# 	WALLET_ID=$(docker exec -it nano-node /usr/bin/nano_node --wallet_list | grep 'Wallet ID' | awk '{ print $NF}')
# 	SEED=$(docker exec -it nano-node /usr/bin/nano_node --wallet_decrypt_unsafe --wallet=$WALLET_ID | grep 'Seed' | awk '{ print $NF}' | tr -d '\r')
# 	echo $SEED
# fi

if [[ "$1" = "favorites" ]] || [[ "$1" = "saved" ]]; then

	if [[ $(cat $DIR/.n2-favorites 2>/dev/null) == "" ]]; then
		echo "[{ \"hello\": \"world\"  }]" >> $DIR/.n2-favorites
	fi

	cat $DIR/.n2-favorites

	exit 1

fi

if [[ "$1" = "reset-saved" ]]; then
	rm $DIR/.n2-favorites
	echo "[]" >> $DIR/.n2-favorites
	exit 1
fi

if [[ "$1" = "save" ]] || [[ "$1" = "favorite" ]]; then

	if [[ $(cat $DIR/.n2-favorites 2>/dev/null) == "" ]]; then
		echo "[]" >> $DIR/.n2-favorites
	fi

	if [[ "$2" = "" ]]; then
		echo "${CYAN}Cloud${NC}: Missing Nano Address."
		exit 1
	fi

	if [[ "$3" = "" ]]; then
		echo "${CYAN}Cloud${NC}: Missing Nickname."
		exit 1
	fi

	SAVED="$(cat $DIR/.n2-favorites)" 
	rm $DIR/.n2-favorites 
	jq <<< "$SAVED" | jq ". + [ { \"name\": \"$1\", \"address\": \"$2\" } ]" >> $DIR/.n2-favorites 

	exit

fi


if [[ $1 == "send" ]] || [[ $1 == "--send" ]] || [[ $1 == "-s" ]]; then
	cat <<EOF
$(local_send $2 $3 $4)
EOF
	exit 1
fi


if [[ $1 == "balance" ]] || [[ $1 == "accounts" ]] || [[ $1 == "account" ]] || [[ $1 == "ls" ]]; then

		echo 
cat <<EOF
${GREEN}Local${NC}: N1: Wallet is in-development. 

Github: https://github.com/fwd/n2
Twitter: https://twitter.com/nano2dev
EOF

fi


if [[ "$2" = "setup" ]] || [[ "$2" = "--setup" ]] || [[ "$2" = "install" ]]; then

	if [[ "$OSTYPE" == "linux-gnu"* ]]; then
			echo ""
		elif [[ "$OSTYPE" == "darwin"* ]]; then
			echo "${CYAN}Cloud${NC}: You're on a Mac. OS not supported. Try a Cloud server running Ubuntu."
			sponsor
			exit 1
		  # Mac OSX
		elif [[ "$OSTYPE" == "cygwin" ]]; then
			echo "${CYAN}Cloud${NC}: Operating system not supported."
			sponsor
			exit 1
		  # POSIX compatibility layer and Linux environment emulation for Windows
		elif [[ "$OSTYPE" == "msys" ]]; then
			echo "${CYAN}Cloud${NC}: Operating system not supported."
			sponsor
			exit 1
		  # Lightweight shell and GNU utilities compiled for Windows (part of MinGW)
		elif [[ "$OSTYPE" == "win32" ]]; then
		  # I'm not sure this can happen.
			echo "${CYAN}Cloud${NC}: Operating system not supported."
			sponsor
			exit 1
		elif [[ "$OSTYPE" == "freebsd"* ]]; then
		  # ...
			echo "${CYAN}Cloud${NC}: Operating system not supported."
			sponsor
			exit 1
		else
		   # Unknown.
			echo "${CYAN}Cloud${NC}: Operating system not supported."
			sponsor
			exit 1
		fi

		# Coming soon
		if [[ "$2" = "pow" ]] || [[ "$2" = "--pow" ]] || [[ "$2" = "--pow-server" ]]; then
			read -p 'Setup a Live Nano Node: Enter 'y' to continue: ' YES
			if [[ "$YES" = "y" ]] || [[ "$YES" = "Y" ]]; then
				echo "Coming soon"
				# @reboot ~/nano-work-server/target/release/nano-work-server --gpu 0:0
				# $DIR/nano-work-server/target/release/nano-work-server --cpu 2
				# $DIR/nano-work-server/target/release/nano-work-server --gpu 0:0
				exit 1
			fi
			echo "Canceled"
			exit 1
		fi

	# Sorta working
	if [[ "$2" = "gpu" ]] || [[ "$2" = "--gpu" ]]; then
		read -p 'Setup NVIDIA GPU. Enter 'y' to continue: ' YES
		if [[ "$YES" = "y" ]] || [[ "$YES" = "Y" ]]; then
			sudo apt-get purge nvidia*
			sudo ubuntu-drivers autoinstall
			exit 1
		fi
		echo "Canceled"
		exit 1
	fi

	read -p 'Setup a Live Nano Node: Enter 'y' to continue: ' YES
	if [[ "$YES" = "y" ]] || [[ "$YES" = "Y" ]]; then
		cd $DIR && git clone https://github.com/fwd/nano-docker.git
		LATEST=$(curl -sL https://api.github.com/repos/nanocurrency/nano-node/releases/latest | jq -r ".tag_name")
		cd $DIR/nano-docker && sudo ./setup.sh -s -t $LATEST
		exit 1
	fi
	echo "Canceled"
	exit 1

fi

     
# ██████╗  ██████╗  ██████╗███████╗
# ██╔══██╗██╔═══██╗██╔════╝██╔════╝
# ██║  ██║██║   ██║██║     ███████╗
# ██║  ██║██║   ██║██║     ╚════██║
# ██████╔╝╚██████╔╝╚██████╗███████║
# ╚═════╝  ╚═════╝  ╚═════╝╚══════╝

if [ "$2" = "docs" ] || [ "$2" = "--docs" ] || [ "$2" = "-docs" ] || [ "$2" = "d" ] || [ "$2" = "-d" ]; then
	URL="https://docs.nano.to/n2"
	echo "Visit Docs: $URL"
	open $URL
	exit 1
fi



#  ██████╗██╗  ██╗ █████╗ ██╗███╗   ██╗
# ██╔════╝██║  ██║██╔══██╗██║████╗  ██║
# ██║     ███████║███████║██║██╔██╗ ██║
# ██║     ██╔══██║██╔══██║██║██║╚██╗██║
# ╚██████╗██║  ██║██║  ██║██║██║ ╚████║
#  ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝
                                    
if [ "$2" = "nanolooker" ] || [ "$2" = "--nl" ] || [ "$2" = "-nl" ] || [ "$2" = "-l" ]; then

	if [[ $(cat $DIR/.n2-session 2>/dev/null) == "" ]]; then
		echo "${CYAN}Cloud${NC}: You're not logged in. Use 'n2 login' or 'n2 register' first."
		exit 1
	fi

	ACCOUNT=$(curl -s "https://nano.to/cloud/account" \
	-H "Accept: application/json" \
	-H "session: $(cat $DIR/.n2-session)" \
	-H "Content-Type:application/json" \
	--request GET)

	address=$(jq -r '.address' <<< "$ACCOUNT")

	open "https://nanolooker.com/account/$address"
	echo "==========================================="
	echo "                OPEN LINK                  "
	echo "==========================================="
	echo "https://nanolooker.com/account/$address"
	echo "==========================================="
	exit
fi

# cat <<EOF
# $LOCAL_DOCS
# EOF

# exit 1

# fi


# ██████╗ ██████╗ ██╗ ██████╗███████╗
# ██╔══██╗██╔══██╗██║██╔════╝██╔════╝
# ██████╔╝██████╔╝██║██║     █████╗  
# ██╔═══╝ ██╔══██╗██║██║     ██╔══╝  
# ██║     ██║  ██║██║╚██████╗███████╗
# ╚═╝     ╚═╝  ╚═╝╚═╝ ╚═════╝╚══════╝                                  

if [ "$1" = "price" ] || [ "$1" = "--price" ] || [ "$1" = "-price" ] || [ "$1" = "p" ] || [ "$1" = "-p" ]; then

	if [[ "$2" == "--json" ]]; then
		curl -s "https://nano.to/price?currency=USD" \
		-H "Accept: application/json" \
		-H "Content-Type:application/json" \
		--request GET | jq
		exit 1
	fi

	# AWARD FOR CLEANEST METHOD
	PRICE=$(curl -s "https://nano.to/cloud/price" \
	-H "Accept: application/json" \
	-H "Content-Type:application/json" \
	--request GET)
	# exit 1

	if [[ "$2" == "--json" ]] || [[ "$3" == "--json" ]] || [[ "$4" == "--json" ]] || [[ "$5" == "--json" ]] || [[ "$6" == "--json" ]]; then
		echo $PRICE
		exit 1
	fi

	echo "==============================="
	if [[ $(jq -r '.currency' <<< "$PRICE") == 'USD' ]]; then
		echo "      Ӿ 1.00 = \$ $(jq -r '.price' <<< "$PRICE")"
	else
		echo "      Ӿ 1.00 = $(jq -r '.price' <<< "$PRICE") $(jq -r '.currency' <<< "$PRICE")"
	fi 
	echo "==============================="
	echo "https://coinmarketcap.com/currencies/nano"
	echo "==============================="
	# echo "COINGECKO: https://www.coingecko.com/en/coins/nano/$(jq -r '.currency' <<< "$PRICE" | awk '{print tolower($0)}')"

	exit 1

fi


# -----------------------------------ALIASES------------------------------------#     


if [[ "$1" = "recycle" ]]; then
cat <<EOF
Usage:
  $ n2 cloud recycle
EOF
	exit 1
fi

# -----------------------------------BASEMENT------------------------------------#                                       


# ██╗  ██╗███████╗██╗     ██████╗ 
# ██║  ██║██╔════╝██║     ██╔══██╗
# ███████║█████╗  ██║     ██████╔╝
# ██╔══██║██╔══╝  ██║     ██╔═══╝ 
# ██║  ██║███████╗███████╗██║     
# ╚═╝  ╚═╝╚══════╝╚══════╝╚═╝     

if [ "$1" = "help" ] || [ "$1" = "--help" ] || [ "$1" = "-help" ] || [ "$1" = "-h" ]; then
	echo "$DOCS"
	exit 1
fi

# ██╗   ██╗███████╗██████╗ ███████╗██╗ ██████╗ ███╗   ██╗
# ██║   ██║██╔════╝██╔══██╗██╔════╝██║██╔═══██╗████╗  ██║
# ██║   ██║█████╗  ██████╔╝███████╗██║██║   ██║██╔██╗ ██║
# ╚██╗ ██╔╝██╔══╝  ██╔══██╗╚════██║██║██║   ██║██║╚██╗██║
#  ╚████╔╝ ███████╗██║  ██║███████║██║╚██████╔╝██║ ╚████║
#   ╚═══╝  ╚══════╝╚═╝  ╚═╝╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝                                      

if [[ "$1" = "v" ]] || [[ "$1" = "-v" ]] || [[ "$1" = "--version" ]] || [[ "$1" = "version" ]]; then
	echo "Version: $VERSION"
	exit 1
fi


# ██╗   ██╗██████╗ ██████╗  █████╗ ████████╗███████╗
# ██║   ██║██╔══██╗██╔══██╗██╔══██╗╚══██╔══╝██╔════╝
# ██║   ██║██████╔╝██║  ██║███████║   ██║   █████╗  
# ██║   ██║██╔═══╝ ██║  ██║██╔══██║   ██║   ██╔══╝  
# ╚██████╔╝██║     ██████╔╝██║  ██║   ██║   ███████╗
#  ╚═════╝ ╚═╝     ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚══════╝
                                                  
if [ "$1" = "u" ] || [ "$2" = "-u" ] || [ "$1" = "install" ] || [ "$1" = "--install" ]  || [ "$1" = "--update" ] || [ "$1" = "update" ]; then
	if [ "$2" = "--dev" ] || [ "$2" = "dev" ]; then
		sudo rm /usr/local/bin/n2
		curl -s -L "https://github.com/fwd/n2/raw/dev/n2.sh" -o /usr/local/bin/n2
		sudo chmod +x /usr/local/bin/n2
		echo "Installed latest 'development' version."
		exit 1
	fi
	if [ "$2" = "--prod" ] || [ "$2" = "prod" ]; then
		sudo rm /usr/local/bin/n2
		curl -s -L "https://github.com/fwd/n2/raw/master/n2.sh" -o /usr/local/bin/n2
		sudo chmod +x /usr/local/bin/n2
		echo "Installed latest 'stable' version."
		exit 1
	fi
	curl -s -L "https://github.com/fwd/n2/raw/master/n2.sh" -o /usr/local/bin/n2
	sudo chmod +x /usr/local/bin/n2
	echo "Installed latest version."
	exit 1
fi


# ██╗   ██╗███╗   ██╗██╗███╗   ██╗███████╗████████╗ █████╗ ██╗     ██╗     
# ██║   ██║████╗  ██║██║████╗  ██║██╔════╝╚══██╔══╝██╔══██╗██║     ██║     
# ██║   ██║██╔██╗ ██║██║██╔██╗ ██║███████╗   ██║   ███████║██║     ██║     
# ██║   ██║██║╚██╗██║██║██║╚██╗██║╚════██║   ██║   ██╔══██║██║     ██║     
# ╚██████╔╝██║ ╚████║██║██║ ╚████║███████║   ██║   ██║  ██║███████╗███████╗
#  ╚═════╝ ╚═╝  ╚═══╝╚═╝╚═╝  ╚═══╝╚══════╝   ╚═╝   ╚═╝  ╚═╝╚══════╝╚══════╝

if [[ "$1" = "--uninstall" ]] || [[ "$1" = "-u" ]]; then
	sudo rm /usr/local/bin/n2
	rm $DIR/.n2-favorites
	rm $DIR/.n2-session
	rm $DIR/.n2-rpc
	echo "CLI removed. Thanks for using N1. Hope to see you soon."
	exit 1
fi


# ██╗  ██╗██╗   ██╗██╗  ██╗
# ██║  ██║██║   ██║██║  ██║
# ███████║██║   ██║███████║
# ██╔══██║██║   ██║██╔══██║
# ██║  ██║╚██████╔╝██║  ██║
# ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝
                         
cat <<EOF
Commant not found. Use 'n2 help' to see all commands.
EOF
