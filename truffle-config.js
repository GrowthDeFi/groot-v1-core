require('dotenv').config();
const HDWalletProvider = require('@truffle/hdwallet-provider');
const privateKey = process.env['PRIVATE_KEY'];
const infuraProjectId = process.env['INFURA_PROJECT_ID'];

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
    mainnet: {
      network_id: 1,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://mainnet.infura.io/ws/v3/' + infuraProjectId),
    },
    ropsten: {
      network_id: 3,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://ropsten.infura.io/ws/v3/' + infuraProjectId),
      skipDryRun: true,
    },
    rinkeby: {
      network_id: 4,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://rinkeby.infura.io/ws/v3/' + infuraProjectId),
      skipDryRun: true,
    },
    kovan: {
      network_id: 42,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://kovan.infura.io/ws/v3/' + infuraProjectId),
      skipDryRun: true,
    },
    goerli: {
      network_id: 5,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://goerli.infura.io/ws/v3/' + infuraProjectId),
      skipDryRun: true,
    },
    bscmain: {
      network_id: 56,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(privateKey, 'wss://bsc-dataseed.binance.org/'),
      skipDryRun: true,
    },
    chapel: {
      network_id: 97,
      networkCheckTimeout: 10000, // fixes truffle/infura bug
      provider: () => new HDWalletProvider(mnemonic, 'wss://data-seed-prebsc-1-s1.binance.org:8545/'),
      skipDryRun: true,
    },
  },
};
