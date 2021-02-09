// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GLPMining } from "./GLPMining.sol";

import { Transfers } from "./modules/Transfers.sol";
import { UniswapV2LiquidityPoolAbstraction } from "./modules/UniswapV2LiquidityPoolAbstraction.sol";

/**
 * @notice This contract implements liquidity mining for staking Uniswap V2
 * shares.
 */
contract GLPMiningToken is ERC20, Ownable, ReentrancyGuard, GLPMining
{
	uint256 constant MAXIMUM_PERFORMANCE_FEE = 50e16; // 50%
	uint256 constant DEFAULT_PERFORMANCE_FEE = 10e16; // 10%

	address public immutable override reserveToken;
	address public immutable override rewardsToken;

	address public override treasury;

	uint256 public override performanceFee = DEFAULT_PERFORMANCE_FEE;
	uint256 public override rewardPerBlock = 0;

	uint256 lastContractBlock = block.number;
	uint256 lastUnlockedReward = 0;
	uint256 lastLockedReward = 0;

	uint256 lastTotalSupply = 1;
	uint256 lastTotalReserve = 1;

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _rewardsToken)
		ERC20(_name, _symbol) public
	{
		address _treasury = msg.sender;
		_setupDecimals(_decimals);
		assert(_reserveToken != address(0));
		assert(_rewardsToken != address(0));
		assert(_reserveToken != _rewardsToken);
		reserveToken = _reserveToken;
		rewardsToken = _rewardsToken;
		treasury = _treasury;
		// just after creation it must transfer 1 wei from reserveToken
		// into this contract
		// this must be performed manually because we cannot approve
		// the spending by this contract before it exists
		// Transfers._pullFunds(_reserveToken, _from, 1);
		_mint(address(this), 1);
	}

	function calcSharesFromCost(uint256 _cost) public view override returns (uint256 _shares)
	{
		return _cost.mul(totalSupply()).div(totalReserve());
	}

	function calcCostFromShares(uint256 _shares) public view override returns (uint256 _cost)
	{
		return _shares.mul(totalReserve()).div(totalSupply());
	}

	function calcSharesFromTokenAmount(address _token, uint256 _amount) external view override returns (uint256 _shares)
	{
		uint256 _cost = UniswapV2LiquidityPoolAbstraction._estimateJoinPool(reserveToken, _token, _amount);
		return calcSharesFromCost(_cost);
	}

	function calcTokenAmountFromShares(address _token, uint256 _shares) external view override returns (uint256 _amount)
	{
		uint256 _cost = calcCostFromShares(_shares);
		return UniswapV2LiquidityPoolAbstraction._estimateExitPool(reserveToken, _token, _cost);
	}

	function totalReserve() public view override returns (uint256 _totalReserve)
	{
		return Transfers._getBalance(reserveToken);
	}

	function rewardInfo() external view override returns (uint256 _lockedReward, uint256 _unlockedReward)
	{
		(, _lockedReward, _unlockedReward) = _calcCurrentRewards();
		return (_lockedReward, _unlockedReward);
	}

	function pendingFees() external view override returns (uint256 _feeShares)
	{
		return _calcFees();
	}

	function deposit(uint256 _cost) external override nonReentrant
	{
		address _from = msg.sender;
		uint256 _shares = calcSharesFromCost(_cost);
		Transfers._pullFunds(reserveToken, _from, _cost);
		_mint(_from, _shares);
	}

	function withdraw(uint256 _shares) external override nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
	}

	function depositToken(address _token, uint256 _amount, uint256 _minShares) external override nonReentrant
	{
		address _from = msg.sender;
		uint256 _minCost = calcCostFromShares(_minShares);
		Transfers._pullFunds(_token, _from, _amount);
		uint256 _cost = UniswapV2LiquidityPoolAbstraction._joinPool(reserveToken, _token, _amount, _minCost);
		uint256 _shares = _cost.mul(totalSupply()).div(totalReserve().sub(_cost));
		_mint(_from, _shares);
	}

	function withdrawToken(address _token, uint256 _shares, uint256 _minAmount) external override nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		uint256 _amount = UniswapV2LiquidityPoolAbstraction._exitPool(reserveToken, _token, _cost, _minAmount);
		Transfers._pushFunds(_token, _from, _amount);
		_burn(_from, _shares);
	}

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

	function setTreasury(address _newTreasury) external override onlyOwner nonReentrant
	{
		require(_newTreasury != address(0), "invalid address");
		address _oldTreasury = treasury;
		treasury = _newTreasury;
		emit ChangeTreasury(_oldTreasury, _newTreasury);
	}

	function setPerformanceFee(uint256 _newPerformanceFee) external override onlyOwner nonReentrant
	{
		require(_newPerformanceFee <= MAXIMUM_PERFORMANCE_FEE, "invalid rate");
		uint256 _oldPerformanceFee = performanceFee;
		performanceFee = _newPerformanceFee;
		emit ChangePerformanceFee(_oldPerformanceFee, _newPerformanceFee);
	}

	function setRewardPerBlock(uint256 _newRewardPerBlock) external override onlyOwner nonReentrant
	{
		(lastContractBlock, lastLockedReward, lastUnlockedReward) = _calcCurrentRewards();
		// require(_newRewardPerBlock <= 1e18, "invalid rate");
		uint256 _oldRewardPerBlock = rewardPerBlock;
		rewardPerBlock = _newRewardPerBlock;
		emit ChangeRewardPerBlock(_oldRewardPerBlock, _newRewardPerBlock);
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

	function _calcCurrentRewards() internal view returns (uint256 _currentContractBlock, uint256 _currentLockedReward, uint256 _currentUnlockedReward)
	{
		uint256 _contractBlock = lastContractBlock;
		uint256 _lockedReward = lastLockedReward;
		uint256 _unlockedReward = lastUnlockedReward;
		if (_contractBlock < block.number) {
			uint256 _blocks = block.number.sub(_contractBlock);
			uint256 _reward = _blocks.mul(rewardPerBlock);
			_contractBlock = block.number;
			_lockedReward = _lockedReward.sub(_reward);
			_unlockedReward = _unlockedReward.add(_reward);
		}
		return (_contractBlock, _lockedReward, _unlockedReward);
	}
}
