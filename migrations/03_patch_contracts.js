const Deployer = artifacts.require('Deployer');
const Patcher1 = artifacts.require('Patcher1');
const LibPatcher1 = artifacts.require('LibPatcher1');
const LibPatcher2 = artifacts.require('LibPatcher2');
const LibPatcher3 = artifacts.require('LibPatcher3');

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(LibPatcher1);
  await deployer.deploy(LibPatcher2);
  await deployer.deploy(LibPatcher3);
  deployer.link(LibPatcher1, Patcher1);
  deployer.link(LibPatcher2, Patcher1);
  deployer.link(LibPatcher3, Patcher1);
  await deployer.deploy(Patcher1);

  if (['development'].includes(network)) {
    console.log('Performing the patch...');
    const contract1 = await Deployer.deployed();
    const contract2 = await Patcher1.deployed();
    await contract2.patch(contract1.address);
  }
};
