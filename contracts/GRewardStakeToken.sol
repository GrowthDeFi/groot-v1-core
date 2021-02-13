// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.6.12;

import { BEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import { ReentrancyGuard } from "@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol";

import { GRewardToken } from "./GRewardToken.sol";

import { Math } from "./modules/Math.sol";
import { Transfers } from "./modules/Transfers.sol";

contract GRewardStakeToken is BEP20, ReentrancyGuard
{
	address public immutable rewardToken;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _rewardToken)
		BEP20(_name, _symbol) public
	{
		require(_decimals == 18, "unsupported decimals");
		rewardToken = _rewardToken;
	}

	function mint(address _to, uint256 _amount) external onlyOwner nonReentrant
	{
		_mint(_to, _amount);
	}

	function burn(address _from ,uint256 _amount) external onlyOwner nonReentrant
	{
		_burn(_from, _amount);
	}

	function safeRewardTransfer(address _to, uint256 _amount) external onlyOwner nonReentrant
	{
		uint256 _balance = Transfers._getBalance(rewardToken);
		Transfers._pushFunds(rewardToken, _to, Math._min(_balance, _amount));
	}
}
