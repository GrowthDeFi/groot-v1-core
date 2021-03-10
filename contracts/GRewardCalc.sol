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

	function _calcUpdateContract() internal view returns (uint256 _lastCumulativeStake, uint256 _lastCumulativeReward)
	{
		uint256 _lastBlock = accounts[CONTRACT].lastBlock;
		_lastCumulativeStake = accounts[CONTRACT].lastCumulativeStake;
		_lastCumulativeReward = accounts[CONTRACT].lastCumulativeReward;
		if (block.number > _lastBlock) {
			uint256 _n = block.number - _lastBlock;
			_lastCumulativeStake = _lastCumulativeStake.add(_n.mul(accounts[CONTRACT].amount));
			_lastCumulativeReward = _lastCumulativeReward.add(_n.mul(rewardPerBlock));
		}
	}

	function _calcUpdateAccount(address _account) internal view returns (uint256 _lastCumulativeStake, uint256 _lastCumulativeReward)
	{
		assert(_account != CONTRACT);
		uint256 _lastBlock = accounts[_account].lastBlock;
		_lastCumulativeStake = accounts[_account].lastCumulativeStake;
		_lastCumulativeReward = accounts[_account].lastCumulativeReward;
		if (block.number > _lastBlock) {
			uint256 _n = block.number - _lastBlock;
			_lastCumulativeStake = _lastCumulativeStake.add(_n.mul(accounts[_account].amount));
		}
	}

	function _calcDistributeReward(uint256 _accountStake, uint256 _contractStake, uint256 _contractReward) internal pure returns (uint256 _reward)
	{
		return _contractReward.mul(_accountStake).div(_contractStake);
	}

	function _update(address _account) internal
	{
		assert(_account != CONTRACT);
		(uint256 _contractStake, uint256 _contractReward) = _calcUpdateContract();
		(uint256 _accountStake, uint256 _accountReward) = _calcUpdateAccount(_account);
		uint256 _reward = _calcDistributeReward(_accountStake, _contractStake, _contractReward);
		accounts[CONTRACT].lastBlock = block.number;
		accounts[CONTRACT].lastCumulativeStake = _contractStake.sub(_accountStake);
		accounts[CONTRACT].lastCumulativeReward = _contractReward.sub(_reward);
		accounts[_account].lastBlock = block.number;
		accounts[_account].lastCumulativeStake = 0;
		accounts[_account].lastCumulativeReward = _accountReward.add(_reward);
	}

	function pendingReward(address _account) external view returns (uint256 _pendingReward)
	{
		require(_account != CONTRACT, "invalid account");
		(uint256 _contractStake, uint256 _contractReward) = _calcUpdateContract();
		(uint256 _accountStake, uint256 _accountReward) = _calcUpdateAccount(_account);
		uint256 _reward = _calcDistributeReward(_accountStake, _contractStake, _contractReward);
		return _accountReward.add(_reward);
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
