const Deployer = artifacts.require('Deployer');

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(Deployer);
};
