// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { Transfers } from "./modules/Transfers.sol";

/**
20,000 rAAVE supply:

2,000 for swaps

8,000 for incentives

10,000 for treasury expansion
 */
contract GTokenSwapper is ReentrancyGuard
{
	address public immutable oldToken;
	address public immutable newToken;
	uint256 public immutable oldLimit;
	uint256 public immutable newLimit;

	bool public enabled = false;

	constructor (address _oldToken, uint256 _oldLimit, address _newToken, uint256 _newLimit) public
	{
		oldToken = _oldToken;
		oldLimit = _oldLimit;
		newToken = _newToken;
		newLimit = _newLimit;
	}

	function enable() external nonReentrant
	{
		uint256 _balance = Transfers._getBalance(newToken);
		require(_balance == newLimit, "full amount ownership required");
		enabled = true;
	}

	function swap() external nonReentrant
	{
		address _from = msg.sender;
		require(enabled, "swapping disabled");
		uint256 _oldAmount = IERC20(oldToken).balanceOf(_from);
		uint256 _newAmount = _oldAmount.mul(newLimit).div(oldLimit);
		Transfers._pullFunds(oldToken, _from, _oldAmount);
		Transfers._pushFunds(newToken, _from, _newAmount);
	}
}
