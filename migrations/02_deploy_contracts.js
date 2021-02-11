const Deployer = artifacts.require('Deployer');
const LibDeployer = artifacts.require('LibDeployer');

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibDeployer);
  deployer.link(LibDeployer, Deployer);
  const contract = await deployer.deploy(Deployer);

  console.log('Adding PMINE wallets...');
  const listPMINE = require('./listPMINE.json');
  await contract.registerReceiversPMINE(listPMINE.map(([address,]) => address), listPMINE.map(([,units]) => BigInt(units) * 10n ** 12n));

  console.log('Adding SAFE wallets...');
  const listSAFE = require('./listSAFE.json');
  await contract.registerReceiversSAFE(listSAFE.map(([address,]) => address), listSAFE.map(([,cents]) => BigInt(cents) * 10n ** 16n));

  if (['development'].includes(network)) {
    await contract.deploy();
  }
};
