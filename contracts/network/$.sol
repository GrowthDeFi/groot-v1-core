// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This library is provided for convenience. It is the single source for
 *      the current network and all related hardcoded contract addresses.
 */
library $
{
	enum Network { Mainnet, Ropsten, Rinkeby, Kovan, Goerli }

	Network constant NETWORK = Network.Mainnet;

	function network() internal pure returns (Network _network)
	{
		assembly { _chainid := chainid() }
		if (_chainid == 1) return Network.Mainnet;
		if (_chainid == 3) return Network.Ropsten;
		if (_chainid == 4) return Network.Rinkeby;
		if (_chainid == 42) return Network.Kovan;
		if (_chainid == 5) return Network.Goerli;
		require(false, "unsupported network");
	}

	address constant GRO =
		NETWORK == Network.Mainnet ? 0x09e64c2B61a5f1690Ee6fbeD9baf5D6990F8dFd0 :
		NETWORK == Network.Ropsten ? 0x5BaF82B5Eddd5d64E03509F0a7dBa4Cbf88CF455 :
		NETWORK == Network.Rinkeby ? 0x020e317e70B406E23dF059F3656F6fc419411401 :
		NETWORK == Network.Kovan ? 0xFcB74f30d8949650AA524d8bF496218a20ce2db4 :
		// NETWORK == Network.Goerli ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant WETH =
		NETWORK == Network.Mainnet ? 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2 :
		NETWORK == Network.Ropsten ? 0xc778417E063141139Fce010982780140Aa0cD5Ab :
		NETWORK == Network.Rinkeby ? 0xc778417E063141139Fce010982780140Aa0cD5Ab :
		NETWORK == Network.Kovan ? 0xd0A1E359811322d97991E03f863a0C30C2cF029C :
		NETWORK == Network.Goerli ? 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 :
		0x0000000000000000000000000000000000000000;

	address constant UniswapV2_FACTORY =
		NETWORK == Network.Mainnet ? 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f :
		NETWORK == Network.Ropsten ? 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f :
		NETWORK == Network.Rinkeby ? 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f :
		NETWORK == Network.Kovan ? 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f :
		NETWORK == Network.Goerli ? 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f :
		0x0000000000000000000000000000000000000000;

	address constant UniswapV2_ROUTER02 =
		NETWORK == Network.Mainnet ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Ropsten ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Rinkeby ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Kovan ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		NETWORK == Network.Goerli ? 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D :
		0x0000000000000000000000000000000000000000;
}
