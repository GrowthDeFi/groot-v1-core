const Deployer = artifacts.require('Deployer');
const LibDeployer1 = artifacts.require('LibDeployer1');
const LibDeployer2 = artifacts.require('LibDeployer2');
const LibDeployer3 = artifacts.require('LibDeployer3');
const LibDeployer4 = artifacts.require('LibDeployer4');

function chunks(array, size = 100) {
  const result = [];
  for (let i = 0, j = size; i < array.length; i = j, j += size) {
      result.push(array.slice(i, j));
  }
  return result;
}

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibDeployer1);
  await deployer.deploy(LibDeployer2);
  await deployer.deploy(LibDeployer3);
  await deployer.deploy(LibDeployer4);
  deployer.link(LibDeployer1, Deployer);
  deployer.link(LibDeployer2, Deployer);
  deployer.link(LibDeployer3, Deployer);
  deployer.link(LibDeployer4, Deployer);
  const contract = await deployer.deploy(Deployer);

  const listGROOT = require('./listGROOT.json');
  console.log('Adding ' + listGROOT.length + ' gROOT wallets...');
  for (const list of chunks(listGROOT)) {
    const addresses = list.map(([address,]) => address);
    const amounts = list.map(([,units]) => BigInt(units) * 10n ** 12n);
    await contract.registerReceiversGROOT(addresses, amounts);
  }

  const listSAFE = require('./listSAFE.json');
  console.log('Adding ' + listSAFE.length + ' SAFE wallets...');
  for (const list of chunks(listSAFE)) {
    const addresses = list.map(([address,]) => address);
    const amounts = list.map(([,cents]) => BigInt(cents) * 10n ** 16n);
    await contract.registerReceiversSAFE(addresses, amounts);
  }

  if (['development'].includes(network)) {
    console.log('Performing the deploy...');
    await contract.deploy({ value: Number(350n * 10n ** 18n) });

    console.log('Performing the airdrop...');
    await contract.airdrop();
  }
};
