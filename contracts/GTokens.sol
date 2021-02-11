// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GPlainToken } from "./GPlainToken.sol";

import { $ } from "./network/$.sol";

contract PMINE is GPlainToken
{
	constructor (uint256 _totalSupply)
		GPlainToken("PMINE", "PMINE", 18, _totalSupply) public
	{
	}
}

contract SAFE is GPlainToken
{
	constructor (uint256 _totalSupply)
		GPlainToken("rAAVE Debt Token", "SAFE", 18, _totalSupply) public
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
