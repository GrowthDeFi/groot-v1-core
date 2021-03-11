// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GExchange } from "./GExchange.sol";

import { Transfers } from "./modules/Transfers.sol";

contract GMiningStakingToken is ERC20, Ownable, ReentrancyGuard
{
	using SafeMath for uint256;

	uint256 constant STAKING_FEE = 11e16; // 11%

	uint256 constant STAKING_FEE_TREASURY_SHARE = 727272727272727272; // 8% of 11%
	uint256 constant STAKING_FEE_BUYBACK_SHARE = 181818181818181818; // 2% of 11%
	uint256 constant STAKING_FEE_DEV_SHARE = 90909090909090909; // 1% of 11%

	address public immutable reserveToken;
	address public immutable miningToken;

	address public exchange;
	address public treasury;
	address public dev;

	modifier onlyEOA()
	{
		require(tx.origin == _msgSender(), "not an externally owned account");
		_;
	}

	constructor (string memory _name, string memory _symbol, uint8 _decimals, address _reserveToken, address _miningToken)
		ERC20(_name, _symbol) public
	{
		address _treasury = msg.sender;
		_setupDecimals(_decimals);
		reserveToken = _reserveToken;
		miningToken = _miningToken;
		treasury = _treasury;
		_mint(address(1), 1); // avoids division by zero
	}

	function totalReserve() public view returns (uint256 _totalReserve)
	{
		_totalReserve = Transfers._getBalance(reserveToken);
		if (_totalReserve == uint256(-1)) return _totalReserve;
		return _totalReserve + 1; // avoids division by zero
	}

	function calcSharesFromCost(uint256 _cost) public view returns (uint256 _shares)
	{
		return _cost.mul(totalSupply()).div(totalReserve());
	}

	function calcCostFromShares(uint256 _shares) public view returns (uint256 _cost)
	{
		return _shares.mul(totalReserve()).div(totalSupply());
	}

	function calcFeeFromCost(uint256 _cost) public view returns (uint256 _fee)
	{
		require(exchange != address(0), "exchange not set");
		uint256 _feeCost = _cost.mul(STAKING_FEE).div(1e18);
		return GExchange(exchange).calcConversionFromOutput(miningToken, reserveToken, _feeCost);
	}

	function deposit(uint256 _cost) external onlyEOA nonReentrant
	{
		address _from = msg.sender;
		uint256 _shares = calcSharesFromCost(_cost);
		uint256 _fee = calcFeeFromCost(_cost);
		Transfers._pullFunds(miningToken, _from, _fee);
		Transfers._pullFunds(reserveToken, _from, _cost);
		_mint(_from, _shares);
		_distributeFee(_fee);
	}

	function withdraw(uint256 _shares) external onlyEOA nonReentrant
	{
		address _from = msg.sender;
		uint256 _cost = calcCostFromShares(_shares);
		uint256 _fee = calcFeeFromCost(_cost);
		Transfers._pullFunds(miningToken, _from, _fee);
		Transfers._pushFunds(reserveToken, _from, _cost);
		_burn(_from, _shares);
		_distributeFee(_fee);
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
		Transfers._approveFunds(miningToken, exchange, _buybackFee);
		uint256 _buyback = GExchange(exchange).convertFundsFromInput(miningToken, reserveToken, _buybackFee, 1);
		Transfers._pushFunds(reserveToken, treasury, _buyback);
		Transfers._pushFunds(miningToken, treasury, _treasuryFee);
		Transfers._pushFunds(miningToken, dev, _devFee);
	}

	event ChangeExchange(address _oldExchange, address _newExchange);
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeDev(address _oldDev, address _newDev);
}
