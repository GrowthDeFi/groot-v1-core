const Deployer = artifacts.require('Deployer');
const LibDeployer = artifacts.require('LibDeployer');

function chunks(array, size = 100) {
  const result = [];
  for (let i = 0, j = size; i < array.length; i = j, j += size) {
      result.push(array.slice(i, j));
  }
  return result;
}

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibDeployer);
  deployer.link(LibDeployer, Deployer);
  const contract = await deployer.deploy(Deployer);

  const listPMINE = require('./listPMINE.json');
  console.log('Adding ' + listPMINE.length + ' PMINE wallets...');
  for (const list of chunks(listPMINE)) {
    const addresses = list.map(([address,]) => address);
    const amounts = list.map(([,units]) => BigInt(units) * 10n ** 12n);
    await contract.registerReceiversPMINE(addresses, amounts);
  }

  const listSAFE = require('./listSAFE.json');
  console.log('Adding ' + listSAFE.length + ' SAFE wallets...');
  for (const list of chunks(listSAFE)) {
    const addresses = list.map(([address,]) => address);
    const amounts = list.map(([,cents]) => BigInt(cents) * 10n ** 16n);
    await contract.registerReceiversSAFE(addresses, amounts);
  }

  if (['development'].includes(network)) {
    await contract.deploy();
  }
};
