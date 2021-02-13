// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { SafeMath } from "@pancakeswap/pancake-swap-lib/contracts/math/SafeMath.sol";
import { BEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";
import { ReentrancyGuard } from "@pancakeswap/pancake-swap-lib/contracts/utils/ReentrancyGuard.sol";

import { GExchange } from "./GExchange.sol";
import { MasterChef } from "./MasterChef.sol"; 

import { Transfers } from "./modules/Transfers.sol";
import { PancakeSwapLiquidityPoolAbstraction } from "./modules/PancakeSwapLiquidityPoolAbstraction.sol";

import { Pair } from "./interop/PancakeSwap.sol";

contract GRewardCompoundingStrategyToken is BEP20, ReentrancyGuard
{
	using SafeMath for uint256;

	uint256 constant MAXIMUM_PERFORMANCE_FEE = 50e16; // 50%
	uint256 constant DEFAULT_PERFORMANCE_FEE = 10e16; // 10%

	address immutable masterChef;
	uint256 immutable pid;

	address public immutable /*override*/ reserveToken;
	address public immutable /*override*/ routingToken;
	address public immutable /*override*/ rewardToken;

	address public exchange;
	address public treasury;

	uint256 public /*override*/ performanceFee = DEFAULT_PERFORMANCE_FEE;

	uint256 lastTotalSupply = 1;
	uint256 lastTotalReserve = 1;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _masterChef, uint256 _pid, address _routingToken)
		BEP20(_name, _symbol) public
	{
		address _treasury = msg.sender;
		(IBEP20 _lpToken,,,) = MasterChef(_masterChef).poolInfo(_pid);
		address _reserveToken = address(_lpToken);
		address _rewardToken = address(MasterChef(_masterChef).cake());
		require(_decimals == 18, "unsupported decimals");
		require(_pid >= 1);
		require(_routingToken == Pair(_reserveToken).token0() || _routingToken == Pair(_reserveToken).token1(), "invalid token");
		masterChef = _masterChef;
		pid = _pid;
		reserveToken = _reserveToken;
		routingToken = _routingToken;
		rewardToken = _rewardToken;
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
		(_totalReserve,) = MasterChef(masterChef).userInfo(pid, address(this));
		return _totalReserve;
	}

	function calcSharesFromCost(uint256 _cost) public view /*override*/ returns (uint256 _shares)
	{
		return _cost.mul(totalSupply()).div(totalReserve());
	}

	function calcCostFromShares(uint256 _shares) public view /*override*/ returns (uint256 _cost)
	{
		return _shares.mul(totalReserve()).div(totalSupply());
	}

	function estimatePendingRewards() external view /*override*/ returns (uint256 _rewardsCost)
	{
		require(exchange != address(0), "exchange not set");
		uint256 _rewardAmount = Transfers._getBalance(rewardToken);
		uint256 _routingAmount = _rewardAmount;
		if (routingToken != rewardToken) {
			_routingAmount = GExchange(exchange).calcConversionFromInput(rewardToken, routingToken, _rewardAmount);
		}
		return PancakeSwapLiquidityPoolAbstraction._estimateJoinPool(reserveToken, routingToken, _routingAmount);
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
		Transfers._approveFunds(reserveToken, masterChef, _cost);
		MasterChef(masterChef).deposit(pid, _cost);
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares) external /*override*/ nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		MasterChef(masterChef).withdraw(pid, _cost);
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}

	function gulpRewards(uint256 _minRewardCost) external /*override*/ nonReentrant
	{
		require(exchange != address(0), "exchange not set");
		uint256 _rewardAmount = Transfers._getBalance(rewardToken);
		uint256 _routingAmount = _rewardAmount;
		if (routingToken != rewardToken) {
			_routingAmount = GExchange(exchange).convertFundsFromInput(rewardToken, routingToken, _rewardAmount, 0);
		}
		uint256 _rewardCost = PancakeSwapLiquidityPoolAbstraction._joinPool(reserveToken, routingToken, _routingAmount);
	        require(_rewardCost >= _minRewardCost, "high slippage");
		Transfers._approveFunds(reserveToken, masterChef, _rewardCost);
		MasterChef(masterChef).deposit(pid, _rewardCost);
	}

	function gulpFees() external /*override*/ nonReentrant
	{
		uint256 _feeShares = _calcFees();
		if (_feeShares > 0) {
			lastTotalSupply = totalSupply();
			lastTotalReserve = totalReserve();
			_mint(treasury, _feeShares);
		}
	}

	function setExchange(address _newExchange) external /*override*/ onlyOwner nonReentrant
	{
		address _oldExchange = exchange;
		exchange = _newExchange;
		emit ChangeExchange(_oldExchange, _newExchange);
	}

	function setTreasury(address _newTreasury) external /*override*/ onlyOwner nonReentrant
	{
		require(_newTreasury != address(0), "invalid address");
		address _oldTreasury = treasury;
		treasury = _newTreasury;
		emit ChangeTreasury(_oldTreasury, _newTreasury);
	}

	function setPerformanceFee(uint256 _newPerformanceFee) external /*override*/ onlyOwner nonReentrant
	{
		require(_newPerformanceFee <= MAXIMUM_PERFORMANCE_FEE, "invalid rate");
		uint256 _oldPerformanceFee = performanceFee;
		performanceFee = _newPerformanceFee;
		emit ChangePerformanceFee(_oldPerformanceFee, _newPerformanceFee);
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

	event ChangeExchange(address _oldExchange, address _newExchange);
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangePerformanceFee(uint256 _oldPerformanceFee, uint256 _newPerformanceFee);
}
