require('dotenv').config();
const fs = require('fs');
const axios = require('axios');
const Web3 = require('web3');
const HDWalletProvider = require('@truffle/hdwallet-provider');

const PRIVATE_KEY = process.env['PRIVATE_KEY'];
const BSCSCAN_API_KEY = process.env['BSCSCAN_API_KEY'];

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

function serialize(params) {
  const list = [];
  for (const name in params) {
    const value = params[name];
    list.push(encodeURIComponent(name) + '=' + encodeURIComponent(value));
  }
  return list.join('&');
}

async function urlfetch(method, url, data, headers = {}) {
  try {
    const response = await axios({ method, url, data, headers });
    return response.data;
  } catch (e) {
    if (e.response) {
      console.log(method, url, data, e.message, e.response.status, e.response.data);
      throw new Error(e.message);
    }
    throw e;
  }
}

async function verifyContract(name, address, sourceCode, args, libs, apiKey, testnet = false) {
  // https://bscscan.com/apis#contracts
  const url = 'https://api' + (testnet ? '-testnet' : '') + '.bscscan.com/api';
  const data = {
    apikey: apiKey,
    module: 'contract',
    action: 'verifysourcecode',
    contractaddress: address,
    sourceCode: sourceCode,
    codeformat: 'solidity-single-file',
    contractname: name,
    compilerversion: 'v0.6.12+commit.27d51765', // https://bscscan.com/solcversions
    optimizationUsed: 0,
    runs: 200,
    constructorArguements: args,
    evmversion: '',
    licenseType: 5, // https://BscScan.com/contract-license-types
    libraryname1: libs[0].name,
    libraryaddress1: libs[0].address,
    libraryname2: libs[1].name,
    libraryaddress2: libs[1].address,
    libraryname3: libs[2].name,
    libraryaddress3: libs[2].address,
    libraryname4: libs[3].name,
    libraryaddress4: libs[3].address,
    libraryname5: libs[4].name,
    libraryaddress5: libs[4].address,
    libraryname6: libs[5].name,
    libraryaddress6: libs[5].address,
    libraryname7: libs[6].name,
    libraryaddress7: libs[6].address,
    libraryname8: libs[7].name,
    libraryaddress8: libs[7].address,
    libraryname9: libs[8].name,
    libraryaddress9: libs[8].address,
    libraryname10: libs[9].name,
    libraryaddress10: libs[9].address,
  };
  const headers = {'content-type':'application/x-www-form-urlencoded; charset=UTF-8'};
  const result = await urlfetch('post', url, serialize(data), headers);
  if (result.status !== '1' || result.message !== 'Ok') return result.message;
  return result.result;
}

const HTTP_PROVIDER_URL = {
  'bscmain': 'https://bsc-dataseed.binance.org/',
  'chapel': 'https://data-seed-prebsc-1-s1.binance.org:8545/',
};

function isTestnet(sourceCode) {
  return /NETWORK = Network\.Chapel/.test(sourceCode);
}

function addressOf(name, testnet) {
  const networkId = testnet ? '97' : '56';
  const json = require('../build/contracts/' + name + '.json');
  return json.networks[networkId].address;
}

function instanceOf(web3, name, testnet) {
  const networkId = testnet ? '97' : '56';
  const json = require('../build/contracts/' + name + '.json');
  return new web3.eth.Contract(json.abi, json.networks[networkId].address);
}

async function publishSourceCode(sourceCode, name, args = '', libNames = [], address = null) {
  console.log('Submitting ' + name + ' source code ...');
  const apiKey = BSCSCAN_API_KEY;
  const testnet = isTestnet(sourceCode);
  if (address === null) address = addressOf(name, testnet);
  const libs = libNames.map((name) => ({ name, address: addressOf(name, testnet) }));
  while (libs.length < 10) libs.push({ name: '', address: '' });
  return await verifyContract(name, address, sourceCode, args, libs, apiKey, testnet);
}

async function main(args) {
  const fileName = 'gROOT';
  const name = 'Deployer';
  const args = '';
  const libNames = ['LibDeployer1', 'LibDeployer2', 'LibDeployer3', 'LibDeployer4'];
  const contractList = {
    'GTokenRegistry': { field: 'registry', args: '' },
    'GNativeBridge': { field: 'bridge', args: '' },
//    'GExchangeImpl': { field: 'exchange', args: 'router' },
//    'SAFE': { field: 'SAFE', args: 'totalSupply' },
//    'gROOT': { field: 'gROOT', args: 'totalSupply' },
//    'stkgROOT': { field: 'stkgROOT', args: '_rewardToken' },
//    'MasterChef': { field: 'masterChef', args: 'GRewardToken(_rewardToken), GRewardStakeToken(_rewardStakeToken), _rewardToken, _rewardPerBlock, block.number' },
//    'stkgROOT_BNB': { field: 'stkgROOT_BNB', args: '_masterChef, _pid, _routingToken' },
  };

  const receipts = [];
  const sourceCode = fs.readFileSync(__dirname + '/../' + fileName + '.sol').toString();
  const testnet = isTestnet(sourceCode);
  const network = testnet ? 'chapel' : 'bscmain';
  const web3 = new Web3(new HDWalletProvider(PRIVATE_KEY, HTTP_PROVIDER_URL[network]));
  const receipt = await publishSourceCode(sourceCode, name, args, libNames);
  receipts.push(receipt);
  for (const libName of libNames) {
    const receipt = await publishSourceCode(sourceCode, libName);
    receipts.push(receipt);
  }
  const deployer = instanceOf(web3, name, testnet);
  for (const contractName in contractList) {
    const { field, args } = contractList[contractName];
    const address = await deployer.methods[field]().call();
    const receipt = await publishSourceCode(sourceCode, contractName, args, [], address);
    receipts.push(receipt);
  }
  console.log(receipts);
}

entrypoint(main);
