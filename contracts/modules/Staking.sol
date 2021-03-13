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

	function _latestRewardedBlock(Self storage _self) internal view returns (uint256 _block)
	{
		(_block,,,,) = _calcUpdate(_self, address(0));
		return _block;
	}

	function _totalUnclaimedReward(Self storage _self) internal view returns (uint256 _reward)
	{
		(,,uint256 _contractReward1, uint256 _contractReward2,) = _calcUpdate(_self, address(0));
		return _contractReward1 + _contractReward2;
	}

	function _totalAvailableReward(Self storage _self) internal view returns (uint256 _reward)
	{
		uint256 _balanceReward = Transfers._getBalance(_self.rewardToken);
		uint256 _unclaimedReward = _totalUnclaimedReward(_self);
		return _balanceReward - _unclaimedReward;
	}

	function _unclaimedReward(Self storage _self, address _account) internal view returns (uint256 _reward)
	{
		(,,,,_reward) = _calcUpdate(_self, _account);
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

	function _claim(Self storage _self, address _account, address _receiver) internal returns (uint256 _reward)
	{
		_update(_self, _account);
		_reward = _self.accounts[_account].lastUnclaimedReward;
		_self.accounts[_account].lastUnclaimedReward = 0;
		_self.lastTotalUnclaimedReward2 -= _reward;
		Transfers._pushFunds(_self.rewardToken, _receiver, _reward);
	}

	function _calcUpdate(Self storage _self, address _account) private view returns (uint256 _currentBlock, uint256 _contractStake, uint256 _contractReward1, uint256 _contractReward2, uint256 _accountReward)
	{
		_currentBlock = block.number;
		_contractStake = _self.lastTotalCumulativeStake;
		_contractReward1 = _self.lastTotalUnclaimedReward1;
		_contractReward2 = _self.lastTotalUnclaimedReward2;
		_accountReward = _self.accounts[_account].lastUnclaimedReward;
		{
			uint256 _contractAmount = _self.totalStakedAmount;
			if (_contractAmount > 0) {
				uint256 _contractBlock = _self.lastTotalBlock;
				if (_currentBlock > _contractBlock) {
					uint256 _n = _currentBlock - _contractBlock;
					uint256 _maxn = (uint256(-1) - _contractStake) / _contractAmount;
					if (_n > _maxn) {
						_n = _maxn;
						_currentBlock = _contractBlock + _n;
					}
					if (_currentBlock > _contractBlock) {
						uint256 _additionalStake = _n * _contractAmount;
						_contractStake += _additionalStake;
						uint256 _balance = Transfers._getBalance(_self.rewardToken);
						uint256 _unclaimed = _contractReward1 + _contractReward2;
						uint256 _available = _balance - _unclaimed;
						if (_available > 0) {
							uint256 _rewardPerBlock = _available / _n;
							if (_rewardPerBlock > _self.rewardPerBlock) _rewardPerBlock = _self.rewardPerBlock;
							uint256 _reward = _n * _rewardPerBlock;
							_contractReward1 += _reward;
						}
					}
				}
				uint256 _accountAmount = _self.accounts[_account].stakedAmount;
				if (_accountAmount > 0) {
					uint256 _accountBlock = _self.accounts[_account].lastBlock;
					if (_currentBlock > _accountBlock) {
						uint256 _n = _currentBlock - _accountBlock;
						uint256 _accountStake = _n * _accountAmount;
						_contractStake -= _accountStake;

						uint256 _reward = _contractReward1.mul(_accountStake) / _contractStake;

						_contractReward1 -= _reward;
						_contractReward2 += _reward;
						_accountReward += _reward;
					}
				}
			}
		}
		return (_currentBlock, _contractStake, _contractReward1, _contractReward2, _accountReward);
	}

	function _update(Self storage _self, address _account) private
	{
		(uint256 _currentBlock, uint256 _contractStake, uint256 _contractReward1, uint256 _contractReward2, uint256 _accountReward) = _calcUpdate(_self, _account);
		_self.lastTotalBlock = _currentBlock;
		_self.lastTotalCumulativeStake = _contractStake;
		_self.lastTotalUnclaimedReward1 = _contractReward1;
		_self.lastTotalUnclaimedReward2 = _contractReward2;
		_self.accounts[_account].lastBlock = _currentBlock;
		_self.accounts[_account].lastUnclaimedReward = _accountReward;
	}
}
