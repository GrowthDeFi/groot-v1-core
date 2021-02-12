#!/bin/bash

GAS_LIMIT=100000000

source .env

npx ganache-cli \
	-q \
	-h 0.0.0.0 \
	-i 56 \
	--chainId 56 \
	-l $GAS_LIMIT \
	-f https://bsc-dataseed.binance.org/ \
	--account $PRIVATE_KEY,100000000000000000000000
