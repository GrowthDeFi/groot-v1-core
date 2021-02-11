// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GPlainToken } from "./GPlainToken.sol";
import { GDeflationaryToken } from "./GDeflationaryToken.sol";

import { $ } from "./network/$.sol";

contract PMINE is GPlainToken
{
	constructor (uint256 _totalSupply)
		GPlainToken("PMINE", "PMINE", 18, _totalSupply) public
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
