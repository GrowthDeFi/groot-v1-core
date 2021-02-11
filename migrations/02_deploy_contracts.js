const Deployer = artifacts.require('Deployer');
const LibDeployer = artifacts.require('LibDeployer');

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibDeployer);
  deployer.link(LibDeployer, Deployer);
  const contract = await deployer.deploy(Deployer);
  if (['development'].includes(network)) {
    await contract.registerReceiversPMINE([account], [2000n * 10n ** 18n]);
    await contract.registerReceiversSAFE([account], [168675n * 10n ** 18n]);
    await contract.deploy();
  }
};
