// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This library is provided for convenience. It is the single source for
 *      the current network and all related hardcoded contract addresses.
 */
library $
{
	enum Network { Bscmain, Chapel }

	Network constant NETWORK = Network.Bscmain;

	function network() internal pure returns (Network _network)
	{
		uint256 _chainid;
		assembly { _chainid := chainid() }
		if (_chainid == 56) return Network.Bscmain;
		if (_chainid == 97) return Network.Chapel;
		require(false, "unsupported network");
	}

	address constant ETH =
		NETWORK == Network.Bscmain ? 0x2170Ed0880ac9A755fd29B2688956BD959F933F8 :
		NETWORK == Network.Chapel ? 0xd66c6B4F0be8CE5b39D52E0Fd1344c389929B378 :
		0x0000000000000000000000000000000000000000;

	address constant WBNB =
		NETWORK == Network.Bscmain ? 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c :
		NETWORK == Network.Chapel ? 0xae13d989daC2f0dEbFf460aC112a837C89BAa7cd :
		0x0000000000000000000000000000000000000000;

	address constant PancakeSwap_FACTORY =
		NETWORK == Network.Bscmain ? 0xBCfCcbde45cE874adCB698cC183deBcF17952812 :
		NETWORK == Network.Chapel ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;

	address constant PancakeSwap_ROUTER02 =
		NETWORK == Network.Bscmain ? 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F :
		NETWORK == Network.Chapel ? 0x0000000000000000000000000000000000000000 :
		0x0000000000000000000000000000000000000000;
}
