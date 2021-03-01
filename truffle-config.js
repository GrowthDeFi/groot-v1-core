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
      provider: () => new HDWalletProvider(privateKey, 'https://bsc-dataseed.binance.org/'),
    },
    chapel: {
      network_id: 97,
      provider: () => new HDWalletProvider(privateKey, 'https://data-seed-prebsc-1-s1.binance.org:8545/'),
      skipDryRun: true,
    },
    development: {
      network_id: '*',
      host: 'localhost',
      port: 8545,
      skipDryRun: true,
    },
  },
};
