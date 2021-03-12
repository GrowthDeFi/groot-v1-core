// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

import { Transfers } from "./Transfers.sol";

library Staking
{
	using SafeMath for uint256;

	struct Self {
		address rewardToken;
		uint256 rewardPerBlock;

		uint256 totalStakedAmount;

		uint256 lastTotalBlock;
		uint256 lastTotalCumulativeStake;
		uint256 lastTotalCumulativeReward;

		mapping (address => Account) accounts;
	}

	struct Account {
		uint256 stakedAmount;

		uint256 lastBlock;
		uint256 lastCumulativeReward;
	}

	function _init(Self storage _self, address _rewardToken) internal
	{
		_self.rewardToken = _rewardToken;
	}

	function _setRewardPerBlock(Self storage _self, uint256 _rewardPerBlock) internal
	{
		_self.rewardPerBlock = _rewardPerBlock;
	}

	function _pendingReward(Self storage _self, address _account) internal view returns (uint256 _reward)
	{
		(,,_reward) = _calcUpdate(_self, _account);
		return _reward;
	}

	function _stake(Self storage _self, address _account, uint256 _amount) internal
	{
		_update(_self, _account);
		// assert(_self.accounts[_account].stakedAmount <= _self.totalStakedAmount);
		_self.totalStakedAmount = _self.totalStakedAmount.add(_amount);
		_self.accounts[_account].stakedAmount += _amount;
	}

	function _unstake(Self storage _self, address _account, uint256 _amount) internal
	{
		_update(_self, _account);
		// assert(_self.accounts[_account].stakedAmount <= _self.totalStakedAmount);
		_self.accounts[_account].stakedAmount = _self.accounts[_account].stakedAmount.sub(_amount);
		_self.totalStakedAmount -= _amount;
	}

	function _claim(Self storage _self, address _account) internal
	{
		_update(_self, _account);
		uint256 _reward = _self.accounts[_account].lastCumulativeReward;
		_self.accounts[_account].lastCumulativeReward = 0;
		Transfers._pushFunds(_self.rewardToken, _account, _reward);
	}

	function _calcUpdate(Self storage _self, address _account) private view returns (uint256 _contractStake, uint256 _contractReward, uint256 _accountReward)
	{
		_contractStake = _self.lastTotalCumulativeStake;
		_contractReward = _self.lastTotalCumulativeReward;
		_accountReward = _self.accounts[_account].lastCumulativeReward;
		{
			uint256 _accountBlock = _self.accounts[_account].lastBlock;
			if (block.number > _accountBlock) {
				uint256 _contractBlock = _self.lastTotalBlock;
				if (block.number > _contractBlock) {
					uint256 _contractAmount = _self.totalStakedAmount;
					if (_contractAmount > 0) {
						uint256 _n = block.number - _contractBlock;
						_contractStake = _contractStake.add(_n.mul(_contractAmount));
						_contractReward = _contractReward.add(_n.mul(_self.rewardPerBlock));
					}
				}
				uint256 _accountAmount = _self.accounts[_account].stakedAmount;
				if (_accountAmount > 0) {
					uint256 _n = block.number - _accountBlock;
					uint256 _accountStake = _n.mul(_accountAmount);
					// assert(_accountStake > 0);
					// assert(_contractStake >= _accountStake);
					uint256 _reward = _contractReward.mul(_accountStake) / _contractStake;
					// assert(_contractReward >= _reward);
					_contractStake -= _accountStake;
					_contractReward -= _reward;
					_accountReward = _accountReward.add(_reward);
				}
			}
		}
		return (_contractStake, _contractReward, _accountReward);
	}

	function _update(Self storage _self, address _account) private
	{
		(uint256 _contractStake, uint256 _contractReward, uint256 _accountReward) = _calcUpdate(_self, _account);
		_self.lastTotalBlock = block.number;
		_self.lastTotalCumulativeStake = _contractStake;
		_self.lastTotalCumulativeReward = _contractReward;
		_self.accounts[_account].lastBlock = block.number;
		_self.accounts[_account].lastCumulativeReward = _accountReward;
	}
}
