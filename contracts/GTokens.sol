// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GToken } from "./GToken.sol";
import { GLPMiningToken } from "./GLPMiningToken.sol";

import { $ } from "./network/$.sol";

contract rAAVE is GToken
{
	constructor (uint256 _initialSupply)
		GToken("rebase AAVE", "rAAVE", 18, 20000e18) public
	{
	}
}

contract stkAAVE_rAAVE is GLPMiningToken
{
	constructor (address _AAVE_rAAVE, address _rAAVE)
		GLPMiningToken("staked AAVE/rAAVE", "stkAAVE/rAAVE", 18, _AAVE_rAAVE, _rAAVE) public
	{
	}
}

contract stkGRO_rAAVE is GLPMiningToken
{
	constructor (address _GRO_rAAVE, address _rAAVE)
		GLPMiningToken("staked GRO/rAAVE", "stkGRO/rAAVE", 18, _GRO_rAAVE, _rAAVE) public
	{
	}
}

contract stkETH_rAAVE is GLPMiningToken
{
	constructor (address _ETH_rAAVE, address _rAAVE)
		GLPMiningToken("staked ETH/rAAVE", "stkETH/rAAVE", 18, _ETH_rAAVE, _rAAVE) public
	{
	}
}
