const GBNBBridge = artifacts.require('GBNBBridge');
const GTokenRegistry = artifacts.require('GTokenRegistry');
const GTokenSwapper = artifacts.require('GTokenSwapper');
const PMINE = artifacts.require('PMINE');
const IBEP20 = artifacts.require('IBEP20');
const Factory = artifacts.require('Factory');
const Pair = artifacts.require('Pair');
// const stkBNB_PMINE = artifacts.require('stkBNB_PMINE');

/*
const UniswapV2_FACTORY = {
	'development': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
	'mainnet': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
	'ropsten': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
	'rinkeby': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
	'kovan': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
	'goerli': '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f',
};

const WETH = {
	'development': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
	'mainnet': '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2',
	'ropsten': '0xc778417E063141139Fce010982780140Aa0cD5Ab',
	'rinkeby': '0xc778417E063141139Fce010982780140Aa0cD5Ab',
	'kovan': '0xd0A1E359811322d97991E03f863a0C30C2cF029C',
	'goerli': '0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6',
};

const rAAVE = {
	'development': '0x3371De12E8734c76F70479Dae3A9f3dC80CDCEaB',
	'mainnet': '0x3371De12E8734c76F70479Dae3A9f3dC80CDCEaB',
	'ropsten': '0x0000000000000000000000000000000000000000',
	'rinkeby': '0x0000000000000000000000000000000000000000',
	'kovan': '0x8093f3ed0caec39ff182243362d167714cc02f99',
	'goerli': '0x0000000000000000000000000000000000000000',
};
*/

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

module.exports = async (deployer, network, [account]) => {
  // publish dependencies
  await deployer.deploy(GBNBBridge);
  await deployer.deploy(GTokenRegistry);

  // setup deployment helpers
  const registry = await GTokenRegistry.deployed();

  // publish PMINE contract
  await deployer.deploy(PMINE);
  const pmine = await PMINE.deployed();
  await registry.registerNewToken(pmine.address, ZERO_ADDRESS);

/*
  // publish swapper
  {
    const raave = await IERC20.at(rAAVE[network]);
    const balance = await raave.totalSupply();
    await deployer.deploy(GTokenSwapper, raave.address, balance, pmine.address, BigInt(2000e18));
  }

  {
    // mint GRO
    const gro = await IERC20.at(GRO[network]);
    await faucet.faucet(gro.address, `${1e18}`, { value: `${2e18}` });

    // create pool
    await factory.createPair(gro.address, pmine.address);
    const pair = await Pair.at(await factory.getPair(gro.address, pmine.address));
    await gro.transfer(pair.address, `${1e18}`);
    await pmine.transfer(pair.address, `${1e18}`);
    await pair.mint(account);

    // publish staking contract
    await deployer.deploy(stkGRO_PMINE, pair.address, pmine.address);
    const stkgro_pmine = await stkGRO_PMINE.deployed();
    await pair.transfer(stkgro_pmine.address, `${1}`);
    await registry.registerNewToken(stkgro_pmine.address, ZERO_ADDRESS);

    // stake LP shares
    const shares = await pair.balanceOf(account);
    await pair.approve(stkgro_pmine.address, shares);
    await stkgro_pmine.deposit(shares);
  }

  {
    // mint WETH
    const weth = await IERC20.at(WETH[network]);
    await faucet.faucet(weth.address, `${1e18}`, { value: `${2e18}` });

    // create pool
    await factory.createPair(weth.address, pmine.address);
    const pair = await Pair.at(await factory.getPair(weth.address, pmine.address));
    await weth.transfer(pair.address, `${1e18}`);
    await pmine.transfer(pair.address, `${1e18}`);
    await pair.mint(account);

    // publish staking contract
    await deployer.deploy(stkETH_PMINE, pair.address, pmine.address);
    const stketh_pmine = await stkETH_PMINE.deployed();
    await pair.transfer(stketh_pmine.address, `${1}`);
    await registry.registerNewToken(stketh_pmine.address, ZERO_ADDRESS);

    // stake LP shares
    const shares = await pair.balanceOf(account);
    await pair.approve(stketh_pmine.address, shares);
    await stketh_pmine.deposit(shares);
  }
*/
};
