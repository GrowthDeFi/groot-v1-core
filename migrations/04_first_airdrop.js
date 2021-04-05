const Airdrop = artifacts.require('Airdrop');
const IERC20 = artifacts.require('IERC20');
const Router02 = artifacts.require('Router02');

function chunks(array, size = 100) {
  const result = [];
  for (let i = 0, j = size; i < array.length; i = j, j += size) {
      result.push(array.slice(i, j));
  }
  return result;
}

const PancakeSwap_ROUTER02 = {
	'development': '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F',
	'bscmain': '0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F',
	'chapel': '0x428E5Be012f8D9cca6852479e522B75519E10980',
};

const WBNB = {
	'development': '0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c',
	'bscmain': '0xd21BB48C35e7021Bf387a8b259662dC06a9df984',
	'chapel': '',
};

const gROOT = {
	'development': '0x8B571fE684133aCA1E926bEB86cb545E549C832D',
	'bscmain': '0x8B571fE684133aCA1E926bEB86cb545E549C832D',
	'chapel': '0x1d33dc9972eec66b95869c7d4d712afe27bf5e7c',
};

module.exports = async (deployer, network, [account]) => {
  await deployer.deploy(Airdrop);

  const router = await Router02.at(PancakeSwap_ROUTER02[network]);
  const wbnb = await IERC20.at(WBNB[network]);
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
  const value = `${999e18}`;
  const amount = `${100e18}`;
  await router.swapETHForExactTokens(amount, [wbnb.address, token.address], account, 2n ** 256n - 1n, { value });
  await token.approve(contract.address, amount);
  await contract.airdrop(listId, 0);
};
