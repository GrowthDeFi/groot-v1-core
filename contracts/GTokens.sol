// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GRewardToken } from "./GRewardToken.sol";
import { GRewardStakeToken } from "./GRewardStakeToken.sol";
import { GDeflationaryToken } from "./GDeflationaryToken.sol";
import { GRewardCompoundingStrategyToken } from "./GRewardCompoundingStrategyToken.sol";

import { $ } from "./network/$.sol";

contract gROOT is GRewardToken
{
	constructor (uint256 _totalSupply)
		GRewardToken("Test Token 1", "TEST1", 18, _totalSupply) public
	{
	}
}

contract stkgROOT is GRewardStakeToken
{
	constructor (address _gROOT)
		GRewardStakeToken("Test Token 4", "TEST4", 18, _gROOT) public
	{
	}
}

contract SAFE is GDeflationaryToken
{
	constructor (uint256 _totalSupply)
		GDeflationaryToken("Test Token 2", "TEST2", 18, _totalSupply) public
	{
	}
}

contract stkgROOT_BNB is GRewardCompoundingStrategyToken
{
	constructor (address _masterChef, uint256 _pid, address _gROOT)
		GRewardCompoundingStrategyToken("Test Token 3", "TEST3", 18, _masterChef, _pid, _gROOT) public
	{
	}
}
