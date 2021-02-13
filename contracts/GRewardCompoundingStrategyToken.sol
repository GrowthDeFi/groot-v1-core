// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import { BEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import { ReentrancyGuard } from "@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol";

import { MasterChef } from "./MasterChef.sol"; 

import { Transfers } from "./modules/Transfers.sol";

contract GRewardCompoundingStrategyToken is BEP20, ReentrancyGuard
{
	using SafeMath for uint256;

	uint256 constant MAXIMUM_PERFORMANCE_FEE = 50e16; // 50%
	uint256 constant DEFAULT_PERFORMANCE_FEE = 10e16; // 10%

	address immutable masterChef;
	uint256 immutable pid;

	address public immutable /*override*/ reserveToken;
/*
	address public immutable override rewardsToken;
*/
	address public treasury;

	uint256 public /*override*/ performanceFee = DEFAULT_PERFORMANCE_FEE;

	uint256 lastTotalSupply = 1;
	uint256 lastTotalReserve = 1;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _masterChef, uint256 _pid/*, address _rewardsToken*/)
		BEP20(_name, _symbol) public
	{
		address _treasury = msg.sender;
		(IBEP20 _lpToken,,,) = MasterChef(_masterChef).poolInfo(_pid);
		require(_decimals == 18, "unsupported decimals");
		require(_pid >= 1);
		// assert(_reserveToken != _rewardsToken);
		masterChef = _masterChef;
		pid = _pid;
		reserveToken = address(_lpToken);
		// rewardsToken = _rewardsToken;
		treasury = _treasury;
	}

	// IMPORTANT just after creation we must call this method
	function bootstrap() external onlyOwner nonReentrant
	{
		address _from = msg.sender;
		uint256 _totalSupply = totalSupply();
		uint256 _totalReserve = totalReserve();
		require(_totalSupply == 0 && _totalReserve == 0, "illegal state");
		Transfers._pullFunds(reserveToken, _from, 1);
		_mint(address(this), 1);
	}

	function totalReserve() public view /*override*/ returns (uint256 _totalReserve)
	{
		uint256 _balance = Transfers._getBalance(reserveToken);
		(uint256 _staked,) = MasterChef(masterChef).userInfo(pid, address(this));
		return _balance.add(_staked);
	}

	function calcSharesFromCost(uint256 _cost) public view /*override*/ returns (uint256 _shares)
	{
		return _cost.mul(totalSupply()).div(totalReserve());
	}

	function calcCostFromShares(uint256 _shares) public view /*override*/ returns (uint256 _cost)
	{
		return _shares.mul(totalReserve()).div(totalSupply());
	}

	function pendingFees() external view /*override*/ returns (uint256 _feeShares)
	{
		return _calcFees();
	}

	function deposit(uint256 _cost) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _shares = calcSharesFromCost(_cost);
		Transfers._pullFunds(reserveToken, _from, _cost);
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}
/*
	function gulpRewards(uint256 _minCost) external override nonReentrant
	{
		(lastContractBlock, lastLockedReward, lastUnlockedReward) = _calcCurrentRewards();
		uint256 _balanceReward = Transfers._getBalance(rewardsToken);
		uint256 _totalReward = lastLockedReward.add(lastUnlockedReward);
		if (_balanceReward > _totalReward) {
			uint256 _newLockedReward = _balanceReward.sub(_totalReward);
			lastLockedReward = lastLockedReward.add(_newLockedReward);
		}
		UniswapV2LiquidityPoolAbstraction._joinPool(reserveToken, rewardsToken, lastUnlockedReward, _minCost);
		lastUnlockedReward = 0;
		assert(lastLockedReward.add(lastUnlockedReward) == Transfers._getBalance(rewardsToken));
	}

	function gulpFees() external override nonReentrant
	{
		uint256 _feeShares = _calcFees();
		if (_feeShares > 0) {
			lastTotalSupply = totalSupply();
			lastTotalReserve = totalReserve();
			_mint(treasury, _feeShares);
		}
	}
*/
	function setTreasury(address _newTreasury) external /*override*/ onlyOwner nonReentrant
	{
		require(_newTreasury != address(0), "invalid address");
		// address _oldTreasury = treasury;
		treasury = _newTreasury;
		// emit ChangeTreasury(_oldTreasury, _newTreasury);
	}

	function setPerformanceFee(uint256 _newPerformanceFee) external /*override*/ onlyOwner nonReentrant
	{
		require(_newPerformanceFee <= MAXIMUM_PERFORMANCE_FEE, "invalid rate");
		// uint256 _oldPerformanceFee = performanceFee;
		performanceFee = _newPerformanceFee;
		// emit ChangePerformanceFee(_oldPerformanceFee, _newPerformanceFee);
	}

	function _calcFees() internal view returns (uint256 _feeShares)
	{
		uint256 _oldTotalSupply = lastTotalSupply;
		uint256 _oldTotalReserve = lastTotalReserve;

		uint256 _newTotalSupply = totalSupply();
		uint256 _newTotalReserve = totalReserve();

		// calculates the profit using the following formula
		// ((P1 - P0) * S1 * f) / P1
		// where P1 = R1 / S1 and P0 = R0 / S0
		uint256 _positive = _oldTotalSupply.mul(_newTotalReserve);
		uint256 _negative = _newTotalSupply.mul(_oldTotalReserve);
		if (_positive > _negative) {
			uint256 _profitCost = _positive.sub(_negative).div(_oldTotalSupply);
			uint256 _feeCost = _profitCost.mul(performanceFee).div(1e18);
			return calcSharesFromCost(_feeCost);
		}

		return 0;
	}
}
