// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GRewardToken } from "./GRewardToken.sol";
import { GRewardStakeToken } from "./GRewardStakeToken.sol";
import { GDeflationaryToken } from "./GDeflationaryToken.sol";

import { $ } from "./network/$.sol";

contract gROOT is GRewardToken
{
	constructor (uint256 _totalSupply)
		GRewardToken("growth Root Token", "gROOT", 18, _totalSupply) public
	{
	}
}

contract stkgROOT is GRewardStakeToken
{
	constructor (address _gROOT)
		GRewardStakeToken("stake gROOT", "stkgROOT", 18, _gROOT) public
	{
	}
}

contract SAFE is GDeflationaryToken
{
	constructor (uint256 _totalSupply)
		GDeflationaryToken("rAAVE Debt Token", "SAFE", 18, _totalSupply) public
	{
	}
}
