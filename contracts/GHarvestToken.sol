// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeMath } from "@openzeppelin/contracts/math/SafeMath.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import { GExchange } from "./GExchange.sol";

import { Staking } from "./modules/Staking.sol";
import { Transfers } from "./modules/Transfers.sol";
import { Wrapping } from "./modules/Wrapping.sol";

import { $ } from "./network/$.sol";

contract GHarvestToken is ERC20, Ownable, ReentrancyGuard
{
	using SafeMath for uint256;
	using Staking for Staking.Self;
	using EnumerableSet for EnumerableSet.AddressSet;

	uint256 constant STAKING_FEE = 11e16; // 11%

	uint256 constant STAKING_FEE_TREASURY_SHARE = 727272727272727272; // 8% of 11%
	uint256 constant STAKING_FEE_BUYBACK_SHARE = 181818181818181818; // 2% of 11%
	uint256 constant STAKING_FEE_DEV_SHARE = 90909090909090910; // 1% of 11%

	address public immutable reserveToken;
	address public immutable feeToken;

	address public exchange;
	address public treasury;
	address public dev;

	Staking.Self private staking;

	EnumerableSet.AddressSet private whitelist;

	modifier onlyEOAorWhitelist()
	{
		address _from = _msgSender();
		require(tx.origin == _from || whitelist.contains(_from), "access denied");
		_;
	}

	modifier onlyWhitelist()
	{
		address _from = _msgSender();
		require(whitelist.contains(_from), "access denied");
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

	function totalReserve() external view returns (uint256 _totalReserve)
	{
		return staking.totalStakedAmount;
	}

	function latestRewardedBlock() external view returns (uint256 _block)
	{
		return staking._latestRewardedBlock();
	}

	function totalAvailableReward() external view returns (uint256 _reward)
	{
		return staking._totalAvailableReward();
	}

	function totalUnclaimedReward() external view returns (uint256 _reward)
	{
		return staking._totalUnclaimedReward();
	}

	function unclaimedReward(address _account) external view returns (uint256 _reward)
	{
		return staking._unclaimedReward(_account);
	}

	function calcFee(uint256 _amount) public view returns (uint256 _fee)
	{
		require(exchange != address(0), "exchange not set");
		uint256 _feeAmount = _amount.mul(STAKING_FEE) / 1e18;
		return GExchange(exchange).calcConversionFromOutput(feeToken, reserveToken, _feeAmount);
	}

	function deposit(uint256 _amount) external onlyEOAorWhitelist nonReentrant
	{
		address _from = msg.sender;
		_deposit(_from, _amount, _from, _from, uint256(-1));
	}

	function depositTo(uint256 _amount, address _to) external onlyWhitelist nonReentrant
	{
		address _from = msg.sender;
		_deposit(_from, _amount, _to, _from, uint256(-1));
	}

	function withdraw(uint256 _amount) external onlyEOAorWhitelist nonReentrant
	{
		address _from = msg.sender;
		_withdraw(_from, _amount, _from, _from, uint256(-1));
	}

	function claim() external onlyEOAorWhitelist nonReentrant
	{
		address _from = msg.sender;
		staking._claim(_from, _from);
	}

	function depositBNB(uint256 _amount) external payable onlyEOAorWhitelist nonReentrant
	{
		address payable _from = msg.sender;
		uint256 _value = msg.value;
		require(feeToken == $.WBNB, "unsupported function");
		Wrapping._wrap(_value);
		uint256 _feeChange = _deposit(_from, _amount, _from, address(this), _value);
		Wrapping._unwrap(_feeChange);
		_from.transfer(_feeChange);
	}

	/*
	function depositToBNB(uint256 _amount, address payable _to) external payable onlyWhitelist nonReentrant
	{
		address _from = msg.sender;
		uint256 _value = msg.value;
		require(feeToken == $.WBNB, "unsupported function");
		Wrapping._wrap(_value);
		uint256 _feeChange = _deposit(_from, _amount, _to, address(this), _value);
		Wrapping._unwrap(_feeChange);
		_to.transfer(_feeChange);
	}
	*/

	function withdrawBNB(uint256 _amount) external payable onlyEOAorWhitelist nonReentrant
	{
		address payable _from = msg.sender;
		uint256 _value = msg.value;
		require(feeToken == $.WBNB, "unsupported function");
		Wrapping._wrap(_value);
		uint256 _feeChange = _withdraw(_from, _amount, _from, address(this), _value);
		Wrapping._unwrap(_feeChange);
		_from.transfer(_feeChange);
	}

	function claimBNB() external onlyEOAorWhitelist nonReentrant
	{
		address payable _from = msg.sender;
		require(staking.rewardToken == $.WBNB, "unsupported function");
		uint256 _reward = staking._claim(_from, address(this));
		Wrapping._unwrap(_reward);
		_from.transfer(_reward);
	}

	function addToWhitelist(address _address) external onlyOwner nonReentrant
	{
		require(whitelist.add(_address), "already in whitelisted");
	}

	function removeFromWhitelist(address _address) external onlyOwner nonReentrant
	{
		require(whitelist.remove(_address), "not in whitelisted");
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

	function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override
	{
		require(_from == address(0) || _to == address(0), "transfer prohibited");
		_amount; // silences warning
	}

	function _deposit(address _from, uint256 _amount, address _to, address _payer, uint256 _maxFee) internal returns (uint256 _feeChange)
	{
		uint256 _fee = calcFee(_amount);
		require(_fee <= _maxFee, "insufficient fee");
		if (_payer != address(this)) Transfers._pullFunds(feeToken, _payer, _fee);
		Transfers._pullFunds(reserveToken, _from, _amount);
		_mint(_to, _amount);
		staking._stake(_to, _amount);
		_distributeFee(_fee);
		return _maxFee - _fee;
	}

	function _withdraw(address _from, uint256 _amount, address _to, address _payer, uint256 _maxFee) internal returns (uint256 _feeChange)
	{
		uint256 _fee = calcFee(_amount);
		require(_fee <= _maxFee, "insufficient fee");
		if (_payer != address(this)) Transfers._pullFunds(feeToken, _payer, _fee);
		_burn(_from, _amount);
		staking._unstake(_from, _amount);
		Transfers._pushFunds(reserveToken, _to, _amount);
		_distributeFee(_fee);
		return _maxFee - _fee;
	}

	function _distributeFee(uint256 _fee) internal
	{
		uint256 _treasuryFee = (_fee * STAKING_FEE_TREASURY_SHARE) / 1e18;
		uint256 _buybackFee = (_fee * STAKING_FEE_BUYBACK_SHARE) / 1e18;
		uint256 _devFee = _fee - (_treasuryFee + _buybackFee);
		Transfers._approveFunds(feeToken, exchange, _buybackFee);
		uint256 _buyback = GExchange(exchange).convertFundsFromInput(feeToken, reserveToken, _buybackFee, 1);
		Transfers._pushFunds(reserveToken, treasury, _buyback);
		Transfers._pushFunds(feeToken, treasury, _treasuryFee);
		Transfers._pushFunds(feeToken, dev, _devFee);
	}

	event ChangeExchange(address _oldExchange, address _newExchange);
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangeDev(address _oldDev, address _newDev);
	event ChangeRewardPerBlock(uint256 _oldRewardPerBlock, uint256 _newRewardPerBlock);
}

contract GHarvestTokenHelper
{
	using SafeMath for uint256;

	uint256 constant STAKING_FEE = 11e16; // 11%

	modifier onlyEOA()
	{
		require(tx.origin == msg.sender, "access denied");
		_;
	}

	function depositFeeOnly(address _token, uint256 _value) external onlyEOA
	{
		address _from = msg.sender;
		_depositFeeOnly(_token, _from, _value, _from, _from);
	}

	function depositFeeOnlyBNB(address _token) external payable onlyEOA
	{
		address payable _from = msg.sender;
		uint256 _value = msg.value;
		address _feeToken = GHarvestToken(_token).feeToken();
		require(_feeToken == $.WBNB, "unsupported function");
		Wrapping._wrap(_value);
		uint256 _feeChange = _depositFeeOnly(_token, address(this), _value, _from, address(this));
		Wrapping._unwrap(_feeChange);
		_from.transfer(_feeChange);
	}

	function _depositFeeOnly(address _token, address _from, uint256 _value, address _to, address _payer) internal returns (uint256 _feeChange)
	{
		address _reserveToken = GHarvestToken(_token).reserveToken();
		address _feeToken = GHarvestToken(_token).feeToken();
		address _exchange = GHarvestToken(_token).exchange();
		if (_from != address(this)) Transfers._pullFunds(_feeToken, _from, _value);
		uint256 _netValue = _value.mul(1e18) / (1e18 + STAKING_FEE);
		uint256 _maxFee = _value - _netValue;
		Transfers._approveFunds(_feeToken, _exchange, _netValue);
		uint256 _amount = GExchange(_exchange).convertFundsFromInput(_feeToken, _reserveToken, _netValue, 1);
		Transfers._approveFunds(_feeToken, _token, _maxFee);
		Transfers._approveFunds(_reserveToken, _token, _amount);
		GHarvestToken(_token).depositTo(_amount, _to);	
		Transfers._approveFunds(_feeToken, _token, 0);
		_feeChange = Transfers._getBalance(_feeToken);
		if (_payer != address(this)) Transfers._pushFunds(_feeToken, _payer, _feeChange);
		return _feeChange;
	}
}
