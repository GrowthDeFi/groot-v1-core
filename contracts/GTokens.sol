// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GPlainToken } from "./GPlainToken.sol";

import { $ } from "./network/$.sol";

contract PMINE is GPlainToken
{
	constructor ()
		GPlainToken("PMINE", "PMINE", 18, 20000e18) public
	{
	}
}

/*
contract stkBNB_PMINE is GLPMiningToken
{
	constructor (address _BNB_PMINE, address _PMINE)
		GLPMiningToken("staked BNB/PMINE", "stkBNB/PMINE", 18, _BNB_PMINE, _PMINE) public
	{
	}
}
*/
