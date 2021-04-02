require('dotenv').config();
const fs = require('fs');
const Web3 = require('web3');
const HDWalletProvider = require('@truffle/hdwallet-provider');

// process

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

const web3 = new Web3(new HDWalletProvider(privateKey, HTTP_PROVIDER_URL[network]));

const IERC20_ABI = require('../build/contracts/IERC20.json').abi;

function getTransfers(token, options) {
  return new Promise((resolve, reject) => {
    const fromBlock = options.fromBlock || 'earliest';
    const toBlock = options.toBlock || 'latest';
    const contract = new web3.eth.Contract(IERC20_ABI, token);
    contract.getPastEvents('Transfer', { fromBlock, toBlock }, (error, events) => {
      if (error) return reject(error);
      events.sort((event1, event2) => {
        if (event1.blockNumber == event2.blockNumber) {
          return event1.logIndex - event2.logIndex;
        }
        return event1.blockNumber - event2.blockNumber;
      });
      const transfers = events.map((event) => ({
        from: event.returnValues['from'],
        to: event.returnValues['to'],
        value: BigInt(event.returnValues['value']),
      }));
      return resolve(transfers);
    });
  });
}

function replayTransfers(transfers) {
  let totalSupply = 0n;
  const balances = {};
  for (const { from, to, value } of transfers) {
    if (balances[from] === undefined) balances[from] = 0n;
    if (balances[to] === undefined) balances[to] = 0n;
    if (from == '0x0000000000000000000000000000000000000000') {
      totalSupply += value;
      balances[to] += value;
      continue;
    }
    else
    if (to == '0x0000000000000000000000000000000000000000') {
      totalSupply -= value;
      balances[from] -= value;
      continue;
    }
    else {
      balances[from] -= value;
      balances[to] += value;
    }
  }
  const accounts = Object.keys(balances)
    .filter((address) => balances[address] > 0n)
    .map((address) => ({ address, value: balances[address] }));
  return { totalSupply, accounts };
}

const DEFAULT_TOKEN = '0xD93f98b483CC2F9EFE512696DF8F5deCB73F9497'; // stkGRO
const DEFAULT_BLOCK = 'latest';

async function main(args)
{
  const token = args[2] || DEFAULT_TOKEN;
  const block = args[3] || DEFAULT_BLOCK;
  const transfers = await getTransfers(token, { toBlock: block });
  const { totalSupply, accounts } = replayTransfers(transfers);
  console.log(totalSupply, Object.keys(accounts).length);
}

entrypoint(main)
