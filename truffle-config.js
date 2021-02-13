require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');
const privateKey = process.env['PRIVATE_KEY'];

module.exports = {
  compilers: {
    solc: {
      version: '0.6.12',
      optimizer: {
        enabled: false,
        runs: 200,
      },
    },
  },
  networks: {
    bscmain: {
      network_id: 56,
      networkCheckTimeout: 10000, // fixes truffle bug
      provider: () => new HDWalletProvider(privateKey, 'wss://bsc-dataseed.binance.org/'),
      skipDryRun: false,
    },
    chapel: {
      network_id: 97,
      networkCheckTimeout: 10000, // fixes truffle bug
      provider: () => new HDWalletProvider(privateKey, 'wss://data-seed-prebsc-1-s1.binance.org:8545/'),
      skipDryRun: true,
    },
    development: {
      network_id: '*',
      gas: 30000000,
      host: 'localhost',
      port: 8545,
      skipDryRun: true,
    },
  },
};
