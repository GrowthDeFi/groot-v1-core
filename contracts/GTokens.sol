// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GPlainToken } from "./GPlainToken.sol";
import { GLPMiningToken } from "./GLPMiningToken.sol";

import { $ } from "./network/$.sol";

contract PMINE is GPlainToken
{
	constructor ()
		GPlainToken("PMINE", "PMINE", 18, 20000e18) public
	{
	}
}

contract stkGRO_PMINE is GLPMiningToken
{
	constructor (address _GRO_PMINE, address _PMINE)
		GLPMiningToken("staked GRO/PMINE", "stkGRO/PMINE", 18, _GRO_PMINE, _PMINE) public
	{
	}
}

contract stkETH_PMINE is GLPMiningToken
{
	constructor (address _ETH_PMINE, address _PMINE)
		GLPMiningToken("staked ETH/PMINE", "stkETH/PMINE", 18, _ETH_PMINE, _PMINE) public
	{
	}
}
