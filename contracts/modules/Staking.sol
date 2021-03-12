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
		uint256 lastTotalUnclaimedReward1;
		uint256 lastTotalUnclaimedReward2;

		mapping (address => Account) accounts;
	}

	struct Account {
		uint256 stakedAmount;

		uint256 lastBlock;
		uint256 lastUnclaimedReward;
	}

	function _init(Self storage _self, address _rewardToken) internal
	{
		_self.rewardToken = _rewardToken;
	}

	function _setRewardPerBlock(Self storage _self, uint256 _rewardPerBlock) internal
	{
		_self.rewardPerBlock = _rewardPerBlock;
	}

	function _availableReward(Self storage _self) internal view returns (uint256 _reward)
	{
		uint256 _balanceReward = Transfers._getBalance(_self.rewardToken);
		uint256 _unclaimedReward = _self.lastTotalUnclaimedReward1 + _self.lastTotalUnclaimedReward2;
		return _balanceReward - _unclaimedReward;
	}

	function _unclaimedReward(Self storage _self, address _account) internal view returns (uint256 _reward)
	{
		(,,,_reward) = _calcUpdate(_self, _account);
		return _reward;
	}

	function _stake(Self storage _self, address _account, uint256 _amount) internal
	{
		_update(_self, _account);
		_self.totalStakedAmount = _self.totalStakedAmount.add(_amount);
		_self.accounts[_account].stakedAmount += _amount;
	}

	function _unstake(Self storage _self, address _account, uint256 _amount) internal
	{
		_update(_self, _account);
		_self.accounts[_account].stakedAmount = _self.accounts[_account].stakedAmount.sub(_amount);
		_self.totalStakedAmount -= _amount;
	}

	function _claim(Self storage _self, address _account) internal
	{
		_update(_self, _account);
		uint256 _reward = _self.accounts[_account].lastUnclaimedReward;
		_self.accounts[_account].lastUnclaimedReward = 0;
		_self.lastTotalUnclaimedReward2 -= _reward;
		Transfers._pushFunds(_self.rewardToken, _account, _reward);
	}

	function _calcUpdate(Self storage _self, address _account) private view returns (uint256 _contractStake, uint256 _contractReward1, uint256 _contractReward2, uint256 _accountReward)
	{
		_contractStake = _self.lastTotalCumulativeStake;
		_contractReward1 = _self.lastTotalUnclaimedReward1;
		_contractReward2 = _self.lastTotalUnclaimedReward2;
		_accountReward = _self.accounts[_account].lastUnclaimedReward;
		{
			uint256 _accountBlock = _self.accounts[_account].lastBlock;
			if (block.number > _accountBlock) {
				uint256 _contractBlock = _self.lastTotalBlock;
				if (block.number > _contractBlock) {
					uint256 _contractAmount = _self.totalStakedAmount;
					if (_contractAmount > 0) {
						uint256 _n = block.number - _contractBlock;

						_contractStake = _contractStake.add(_n.mul(_contractAmount));

						uint256 _reward = _availableReward(_self);
						uint256 _rewardPerBlock = _reward / _n;
						if (_rewardPerBlock > _self.rewardPerBlock) _rewardPerBlock = _self.rewardPerBlock;
						_reward = _n * _rewardPerBlock;
						_contractReward1 += _reward;
					}
				}
				uint256 _accountAmount = _self.accounts[_account].stakedAmount;
				if (_accountAmount > 0) {
					uint256 _n = block.number - _accountBlock;
					uint256 _accountStake = _n * _accountAmount;
					_contractStake -= _accountStake;

					uint256 _reward = _contractReward1.mul(_accountStake) / _contractStake;

					_contractReward1 -= _reward;
					_contractReward2 += _reward;
					_accountReward += _reward;
				}
			}
		}
		return (_contractStake, _contractReward1, _contractReward2, _accountReward);
	}

	function _update(Self storage _self, address _account) private
	{
		(uint256 _contractStake, uint256 _contractReward1, uint256 _contractReward2, uint256 _accountReward) = _calcUpdate(_self, _account);
		_self.lastTotalBlock = block.number;
		_self.lastTotalCumulativeStake = _contractStake;
		_self.lastTotalUnclaimedReward1 = _contractReward1;
		_self.lastTotalUnclaimedReward2 = _contractReward2;
		_self.accounts[_account].lastBlock = block.number;
		_self.accounts[_account].lastUnclaimedReward = _accountReward;
	}
}
