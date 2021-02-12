#!/bin/bash

GAS_LIMIT=100000000

source .env

npx ganache-cli \
	-q \
	-h 0.0.0.0 \
	-i 97 \
	--chainId 97 \
	-l $GAS_LIMIT \
	-f https://data-seed-prebsc-1-s1.binance.org:8545/ \
	--account $PRIVATE_KEY,100000000000000000000
