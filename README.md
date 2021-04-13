# gROOT V1 Core

[![Truffle CI Actions Status](https://github.com/GrowthDeFi/groot-v1-core/workflows/Truffle%20CI/badge.svg)](https://github.com/GrowthDeFi/groot-v1-core/actions)

This repository contains the source code for the gROOT smart contracts
(Version 1) and related support code.

## Deployed Contracts

| Token        | BSC Address                                                                                                         |
| ------------ | ------------------------------------------------------------------------------------------------------------------- |
| gROOT        | [0x8B571fE684133aCA1E926bEB86cb545E549C832D](https://bscscan.io/address/0x8B571fE684133aCA1E926bEB86cb545E549C832D) |
| SAFE         | [0x16A87D46ec0FC1adCf0d8C22f83632a0B5abDa2c](https://bscscan.io/address/0x16A87D46ec0FC1adCf0d8C22f83632a0B5abDa2c) |
| stkgROOT/BNB | [0x168306da65229417175EB942D15345585429352f](https://bscscan.io/address/0x168306da65229417175EB942D15345585429352f) |
| hrvgROOT     | [0x65d2Ca0A5a34234c36e7b7E752fA67AC2CCBB203](https://bscscan.io/address/0x65d2Ca0A5a34234c36e7b7E752fA67AC2CCBB203) |
| hrvGRO       | [0xDA2AE62e2B71ad3000BB75acdA2F8f68DC88aCE4](https://bscscan.io/address/0xDA2AE62e2B71ad3000BB75acdA2F8f68DC88aCE4) |

## Repository Organization

* [/contracts/](contracts). This folder is where the smart contract source code
  resides.
* [/migrations/](migrations). This folder hosts the relevant set of Truffle
  migration scripts used to publish the smart contracts to the blockchain.
* [/scripts/](scripts). This folder contains a script to run a local fork and
  other useful tasks.
* [/test/](test). This folder contains a set of relevant unit tests for Truffle
  written in Solidity.

## Building, Deploying and Testing

Configuring the repository:

    $ npm i

Compiling the smart contracts:

    $ npm run build

Running the unit tests (locally):

    $ ./scripts/start-bscmain-fork.sh & npm run test:bscmain

Deploying the smart contracts:

    $ npm run deploy:bscmain

_(Standard installation of Node 14.15.4 on Ubuntu 20.04)_
