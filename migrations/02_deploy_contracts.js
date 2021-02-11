const Deployer = artifacts.require('Deployer');
const LibDeployer = artifacts.require('LibDeployer');

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibDeployer);
  deployer.link(LibDeployer, Deployer);
  await deployer.deploy(Deployer);
};
