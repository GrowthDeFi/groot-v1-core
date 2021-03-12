// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GExchange } from "./GExchange.sol";

import { Staking } from "./modules/Staking.sol";
import { Transfers } from "./modules/Transfers.sol";

contract GMiningStakingToken is ERC20, Ownable, ReentrancyGuard
{
	using SafeMath for uint256;
	using Staking for Staking.Self;

	uint256 constant STAKING_FEE = 11e16; // 11%

	uint256 constant STAKING_FEE_TREASURY_SHARE = 727272727272727272; // 8% of 11%
	uint256 constant STAKING_FEE_BUYBACK_SHARE = 181818181818181818; // 2% of 11%
	uint256 constant STAKING_FEE_DEV_SHARE = 90909090909090909; // 1% of 11%

	address public immutable reserveToken;
	address public immutable feeToken;

	address public exchange;
	address public treasury;
	address public dev;

	Staking.Self staking;

	modifier onlyEOA()
	{
		require(tx.origin == _msgSender(), "not an externally owned account");
		_;
	}

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _feeToken, address _rewardToken)
		ERC20(_name, _symbol) public
	{
		address _from = msg.sender;
		assert(_reserveToken != _rewardToken);
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
		feeToken = _feeToken;
		treasury = _from;
		dev = _from;
		staking._init(_rewardToken);
	}

	function rewardToken() external view returns (address _rewardToken)
	{
		return staking.rewardToken;
	}

	function rewardPerBlock() external view returns (uint256 _rewardPerBlock)
	{
		return staking.rewardPerBlock;
	}

	function totalReserve() public view returns (uint256 _totalReserve)
	{
		return staking.totalStakedAmount;
	}

	function calcFee(uint256 _amount) public view returns (uint256 _fee)
	{
		require(exchange != address(0), "exchange not set");
		uint256 _feeAmount = _amount.mul(STAKING_FEE).div(1e18);
		return GExchange(exchange).calcConversionFromOutput(feeToken, reserveToken, _feeAmount);
	}

	function deposit(uint256 _amount) external onlyEOA nonReentrant
	{
		address _from = msg.sender;
		uint256 _fee = calcFee(_amount);
		Transfers._pullFunds(feeToken, _from, _fee);
		_distributeFee(_fee);
		Transfers._pullFunds(reserveToken, _from, _amount);
		_mint(_from, _amount);
		staking._stake(_from, _amount);
	}

	function withdraw(uint256 _amount) external onlyEOA nonReentrant
	{
		address _from = msg.sender;
		uint256 _fee = calcFee(_amount);
		Transfers._pullFunds(feeToken, _from, _fee);
		_distributeFee(_fee);
		staking._unstake(_from, _amount);
		_burn(_from, _amount);
		Transfers._pushFunds(reserveToken, _from, _amount);
	}

	function claim() external onlyEOA nonReentrant
	{
		address _from = msg.sender;
		staking._claim(_from);
	}

	function setExchange(address _newExchange) external onlyOwner nonReentrant
	{
		address _oldExchange = exchange;
		exchange = _newExchange;
		emit ChangeExchange(_oldExchange, _newExchange);
	}

	function setTreasury(address _newTreasury) external onlyOwner nonReentrant
	{
		require(_newTreasury != address(0), "invalid address");
		address _oldTreasury = treasury;
		treasury = _newTreasury;
		emit ChangeTreasury(_oldTreasury, _newTreasury);
	}

	function setDev(address _newDev) external onlyOwner nonReentrant
	{
		require(_newDev != address(0), "invalid address");
		address _oldDev = dev;
		dev = _newDev;
		emit ChangeDev(_oldDev, _newDev);
	}

	function setRewardPerBlock(uint256 _newRewardPerBlock) external onlyOwner nonReentrant
	{
		uint256 _oldRewardPerBlock = staking.rewardPerBlock;
		staking._setRewardPerBlock(_newRewardPerBlock);
		emit ChangeRewardPerBlock(_oldRewardPerBlock, _newRewardPerBlock);
	}

	function _beforeTokenTransfer(address _from, address _to, uint256 /*_amount*/) internal override
	{
		require(_from == address(0) || _to == address(0), "transfer prohibited");
	}

	function _distributeFee(uint256 _fee) internal
	{
		require(exchange != address(0), "exchange not set");
		uint256 _treasuryFee = _fee.mul(STAKING_FEE_TREASURY_SHARE).div(1e18);
		uint256 _devFee = _fee.mul(STAKING_FEE_DEV_SHARE).div(1e18);
		uint256 _buybackFee = _fee.sub(_treasuryFee.add(_devFee));
		Transfers._approveFunds(feeToken, exchange, _buybackFee);
		uint256 _buyback = GExchange(exchange).convertFundsFromInput(feeToken, reserveToken, _buybackFee, 1);
		Transfers._pushFunds(reserveToken, treasury, _buyback);
		Transfers._pushFunds(feeToken, treasury, _treasuryFee);
		Transfers._pushFunds(feeToken, dev, _devFee);
	}

	event ChangeRewardPerBlock(uint256 _oldRewardPerBlock, uint256 _newRewardPerBlock);
	event ChangeExchange(address _oldExchange, address _newExchange);
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeDev(address _oldDev, address _newDev);
}
