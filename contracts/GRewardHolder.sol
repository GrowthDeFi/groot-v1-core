// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Math } from "./modules/Math.sol";
import { Transfers } from "./modules/Transfers.sol";

contract GRewardHolder is Ownable
{
	address public immutable rewardToken;

	constructor (address _rewardToken, address _masterChef) public
	{
		rewardToken = _rewardToken;
		transferOwnership(_masterChef);
	}

	function allocateReward(uint256 _amount) external
	{
		address _from = msg.sender;
		Transfers._pullFunds(rewardToken, _from, _amount);
	}

	function transferReward(address _to, uint256 _amount) external onlyOwner
	{
		uint256 _balance = Transfers._getBalance(rewardToken);
		Transfers._pushFunds(rewardToken, _to, Math._min(_balance, _amount));
	}
}
