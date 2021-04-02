const Airdrop = artifacts.require('Airdrop');
const IERC20 = artifacts.require('IERC20');

function chunks(array, size = 100) {
  const result = [];
  for (let i = 0, j = size; i < array.length; i = j, j += size) {
      result.push(array.slice(i, j));
  }
  return result;
}

const gROOT = {
	'development': '0x8B571fE684133aCA1E926bEB86cb545E549C832D',
	'bscmain': '0x8B571fE684133aCA1E926bEB86cb545E549C832D',
	'chapel': '0x1d33dc9972eec66b95869c7d4d712afe27bf5e7c',
};

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(Airdrop);

  const token = await IERC20.at(gROOT[network]);
  const contract = await Airdrop.deployed();

  const listId = await contract.listCount();
  await contract.createList(token.address, '100 gROOT airdrop for >= 0.1 stkGRO holders');

  const receivers = require('./listAirdrop1.json');
  console.log('Adding ' + receivers.length + ' wallets...');
  for (const list of chunks(receivers)) {
    const addresses = list.map(({ receiver }) => receiver);
    const amounts = list.map(({ amount }) => amount);
    await contract.registerPayments(listId, addresses, amounts);
  }

  console.log('Performing the airdrop...');
  await token.approve(contract.address, 2n ** 256n - 1n);
  await contract.airdrop(listId, 0);
};
