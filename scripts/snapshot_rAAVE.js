require('dotenv').config();
const fs = require('fs');
const Web3 = require('web3');
const HDWalletProvider = require('@truffle/hdwallet-provider');

// process

function idle() {
  return new Promise((resolve, reject) => { });
}

function sleep(delay) {
  return new Promise((resolve, reject) => setTimeout(resolve, delay));
}

function abort(e) {
  e = e || new Error('Program aborted');
  console.error(e.stack);
  process.exit(1);
}

function exit() {
  process.exit(0);
}

function entrypoint(main) {
  const args = process.argv;
  (async () => { try { await main(args); } catch (e) { abort(e); } exit(); })();
}

// web3

const network = process.env['NETWORK'] || 'mainnet';

const infuraProjectId = process.env['INFURA_PROJECT_ID'] || '';

const privateKey = process.env['PRIVATE_KEY'];
if (!privateKey) throw new Error('Unknown private key');

const NETWORK_ID = {
  'mainnet': '1',
  'ropsten': '3',
  'rinkeby': '4',
  'kovan': '42',
  'goerli': '5',
  'development': '1',
};

const networkId = NETWORK_ID[network];

const HTTP_PROVIDER_URL = {
  'mainnet': 'https://mainnet.infura.io/v3/' + infuraProjectId,
  'ropsten': 'https://ropsten.infura.io/v3/' + infuraProjectId,
  'rinkeby': 'https://rinkeby.infura.io/v3/' + infuraProjectId,
  'kovan': 'https://kovan.infura.io/v3/' + infuraProjectId,
  'goerli': 'https://goerli.infura.io/v3/' + infuraProjectId,
  'development': 'http://localhost:8545/',
};

const WEBSOCKET_PROVIDER_URL = {
  'mainnet': 'wss://mainnet.infura.io/ws/v3/' + infuraProjectId,
  'ropsten': 'wss://ropsten.infura.io/ws/v3/' + infuraProjectId,
  'rinkeby': 'wss://rinkeby.infura.io/ws/v3/' + infuraProjectId,
  'kovan': 'wss://kovan.infura.io/ws/v3/' + infuraProjectId,
  'goerli': 'wss://goerli.infura.io/ws/v3/' + infuraProjectId,
  'development': 'http://localhost:8545/',
};

const web3 = new Web3(new HDWalletProvider(privateKey, HTTP_PROVIDER_URL[network]));

function valid(amount, decimals) {
  const regex = new RegExp(`^\\d+${decimals > 0 ? `(\\.\\d{1,${decimals}})?` : ''}$`);
  return regex.test(amount);
}

function coins(units, decimals) {
  if (!valid(units, 0)) throw new Error('Invalid amount');
  if (decimals == 0) return units;
  const s = units.padStart(1 + decimals, '0');
  return s.slice(0, -decimals) + '.' + s.slice(-decimals);
}

function units(coins, decimals) {
  if (!valid(coins, decimals)) throw new Error('Invalid amount');
  let i = coins.indexOf('.');
  if (i < 0) i = coins.length;
  const s = coins.slice(i + 1);
  return coins.slice(0, i) + s + '0'.repeat(decimals - s.length);
}

const rAAVE = [
  {
    'anonymous': false,
    'inputs': [
      {
        'indexed': true,
        'internalType': 'uint256',
        'name': '_epoch',
        'type': 'uint256',
      },
      {
        'indexed': false,
        'internalType': 'uint256',
        'name': '_oldScalingFactor',
        'type': 'uint256',
      },
      {
        'indexed': false,
        'internalType': 'uint256',
        'name': '_newScalingFactor',
        'type': 'uint256',
      }
    ],
    'name': 'Rebase',
    'type': 'event',
  },
  {
    'anonymous': false,
    'inputs': [
      {
        'indexed': true,
        'internalType': 'address',
        'name': 'from',
        'type': 'address',
      },
      {
        'indexed': true,
        'internalType': 'address',
        'name': 'to',
        'type': 'address',
      },
      {
        'indexed': false,
        'internalType': 'uint256',
        'name': 'value',
        'type': 'uint256',
      },
    ],
    'name': 'Transfer',
    'type': 'event',
  },
];

const _rAAVE = '0x3371De12E8734c76F70479Dae3A9f3dC80CDCEaB';

const contract = new web3.eth.Contract(rAAVE, _rAAVE);

const fromBlock = 11797736;
const toBlock = 'latest';

const transactions = {};

function registerTx(event) {
  const txId = event.transactionHash;
  transactions[txId] = transactions[txId] || [];
  transactions[txId].push(event);
}

function processTxs() {
  let scalingFactor = 1000000000000000000n;
  let contractBalance = 0n;
  const accountBalance = {};
  for (const txId in transactions) {
    const events = transactions[txId];
    for (const event of events) {
      if (event.blockNumber < fromBlock) continue;
      if (event.blockNumber > toBlock) continue;
      if (event.address == _rAAVE) {
        if (event.event == 'Rebase') {
          const oldScalingFactor = BigInt(event.returnValues._oldScalingFactor);
          const newScalingFactor = BigInt(event.returnValues._newScalingFactor);
          if (oldScalingFactor != scalingFactor) abort();
          for (const account in accountBalance) {
            accountBalance[account] = accountBalance[account] * newScalingFactor / oldScalingFactor;
          }
          contractBalance = contractBalance * newScalingFactor / oldScalingFactor;
          scalingFactor = newScalingFactor;
        }
        else {
          const from = event.returnValues.from;
          const to = event.returnValues.to;
          const amount = event.returnValues.value;
          if (from == '0x0000000000000000000000000000000000000000') {
            // console.log('mint _rAAVE', from, to, amount);
            contractBalance += BigInt(amount);
            if (accountBalance[to] === undefined) accountBalance[to] = 0n;
            accountBalance[to] += BigInt(amount);
            continue;
          }
          else
          if (to == '0x0000000000000000000000000000000000000000') {
            // console.log('burn _rAAVE', from, to, amount);
            contractBalance -= BigInt(amount);
            if (accountBalance[from] === undefined) accountBalance[from] = 0n;
            accountBalance[from] -= BigInt(amount);
            continue;
          }
          else {
            // console.log('tansfer _rAAVE', from, to, amount);
            if (accountBalance[from] === undefined) accountBalance[from] = 0n;
            accountBalance[from] -= BigInt(amount);
            if (accountBalance[to] === undefined) accountBalance[to] = 0n;
            accountBalance[to] += BigInt(amount);
          }
        }
      }
    }
  }
  const supplyGROOT = 2000n * 10n ** 6n;
  const output = [];
  let totalUnits = 0;
  for (const account in accountBalance) {
    const units = Number(accountBalance[account] * supplyGROOT / contractBalance);
    if (units > 0) {
      output.push([account, units]);
      totalUnits += units;
    }
  }
  output.sort(([,a],[,b]) => a - b);
  const supplyUnits = Number(supplyGROOT);
  const diffUnits = supplyUnits - totalUnits;
  for (let i = 0; i < diffUnits; i++) {
    output[i][1]++;
  }
  console.log(['TOTAL', output.reduce((sum, [,units]) => sum + units, 0), output.length]);
  fs.writeFileSync('listGROOT.json', JSON.stringify(output, undefined, 2));
  exit();
}

contract.getPastEvents('Rebase', { fromBlock, toBlock }, (error, events1) => {
  if (error) {
    console.log(error);
    return;
  }
  contract.getPastEvents('Transfer', { fromBlock, toBlock }, (error, events2) => {
    if (error) {
      console.log(error);
      return;
    }
    const events = [...events1, ...events2];
    events.sort((a, b) => {
      if (a.blockNumber == b.blockNumber) return a.logIndex - b.logIndex;
      return a.blockNumber - b.blockNumber;
    });
    for (const event of events) {
      registerTx(event);
    }
    processTxs();
  });
});
