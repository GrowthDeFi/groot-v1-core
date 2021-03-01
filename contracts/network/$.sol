// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This library is provided for convenience. It is the single source for
 *      the current network and all related hardcoded contract addresses.
 */
library $
{
	enum Network { Bscmain, Chapel }

	Network constant NETWORK = Network.Chapel;

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
		NETWORK == Network.Chapel ? 0xd21BB48C35e7021Bf387a8b259662dC06a9df984 :
		0x0000000000000000000000000000000000000000;

	address constant PancakeSwap_FACTORY =
		NETWORK == Network.Bscmain ? 0xBCfCcbde45cE874adCB698cC183deBcF17952812 :
		NETWORK == Network.Chapel ? 0x1f3F51f2a7Bfe32f34446b3213C130EBB9e287A1 :
		0x0000000000000000000000000000000000000000;

	address constant PancakeSwap_ROUTER02 =
		NETWORK == Network.Bscmain ? 0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F :
		NETWORK == Network.Chapel ? 0x428E5Be012f8D9cca6852479e522B75519E10980 :
		0x0000000000000000000000000000000000000000;

	address constant PancakeSwap_MASTERCHEF =
		NETWORK == Network.Bscmain ? 0x73feaa1eE314F8c655E354234017bE2193C9E24E :
		NETWORK == Network.Chapel ? 0x7C83Cab4B208A0cD5a1b222D8e6f9099C8F37897 :
		0x0000000000000000000000000000000000000000;
}
