// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";

contract GRewardCalc
{
	using SafeMath for uint256;

	address constant CONTRACT = address(0);

	uint256 public rewardPerBlock;

	mapping (address => Account) private accounts;

	struct Account {
		uint256 amount;
		uint256 lastBlock;
		uint256 lastCumulativeStake;
		uint256 lastCumulativeReward;
	}

	function _calcUpdate(address _account) internal view returns (uint256 _contractStake, uint256 _contractReward, uint256 _accountReward)
	{
		_contractStake = accounts[CONTRACT].lastCumulativeStake;
		_contractReward = accounts[CONTRACT].lastCumulativeReward;
		_accountReward = accounts[_account].lastCumulativeReward;
		{
			uint256 _accountBlock = accounts[_account].lastBlock;
			if (block.number > _accountBlock) {
				uint256 _contractBlock = accounts[CONTRACT].lastBlock;
				if (block.number > _contractBlock) {
					uint256 _contractAmount = accounts[CONTRACT].amount;
					if (_contractAmount > 0) {
						uint256 _n = block.number - _contractBlock;
						_contractStake = _contractStake.add(_n.mul(_contractAmount));
						_contractReward = _contractReward.add(_n.mul(rewardPerBlock));
					}
				}
				uint256 _accountAmount = accounts[_account].amount;
				if (_accountAmount > 0) {
					uint256 _n = block.number - _accountBlock;
					uint256 _accountStake = _n.mul(_accountAmount);
					uint256 _reward = _contractReward.mul(_accountStake).div(_contractStake);
					_contractStake = _contractStake.sub(_accountStake);
					_contractReward = _contractReward.sub(_reward);
					_accountReward = _accountReward.add(_reward);
				}
			}
		}
		return (_contractStake, _contractReward, _accountReward);
	}

	function _update(address _account) internal
	{
		(uint256 _contractStake, uint256 _contractReward, uint256 _accountReward) = _calcUpdate(_account);

		accounts[CONTRACT].lastBlock = block.number;
		accounts[CONTRACT].lastCumulativeStake = _contractStake;
		accounts[CONTRACT].lastCumulativeReward = _contractReward;

		accounts[_account].lastBlock = block.number;
		accounts[_account].lastCumulativeReward = _accountReward;
	}

	function pendingReward(address _account) external view returns (uint256 _pendingReward)
	{
		require(_account != CONTRACT, "invalid account");
		(,,_pendingReward) = _calcUpdate(_account);
		return _pendingReward;
	}

	function registerStake(address _account, uint256 _amount) external
	{
		require(_account != CONTRACT, "invalid account");
		_update(_account);
		accounts[_account].amount = accounts[_account].amount.add(_amount);
		accounts[CONTRACT].amount = accounts[CONTRACT].amount.add(_amount);
	}

	function registerUnstake(address _account, uint256 _amount) external
	{
		require(_account != CONTRACT, "invalid account");
		_update(_account);
		accounts[_account].amount = accounts[_account].amount.sub(_amount);
		accounts[CONTRACT].amount = accounts[CONTRACT].amount.sub(_amount);
	}

	function registerClaim(address _account) external returns (uint256 _reward)
	{
		require(_account != CONTRACT, "invalid account");
		_update(_account);
		_reward = accounts[_account].lastCumulativeReward;
		accounts[_account].lastCumulativeReward = 0;
		return _reward;
	}
}
