// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import { Math } from "./modules/Math.sol";

contract GRewardToken is Ownable, ERC20
{
	constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply)
		ERC20(_name, _symbol) public
	{
		address _sender = msg.sender;
		_setupDecimals(_decimals);
		_mint(_sender, _initialSupply);
	}

	function allocateReward(uint256 _amount) external
	{
		address _from = msg.sender;
		address _to = address(this);
		_transfer(_from, _to, _amount);
	}

	function transferReward(address _to, uint256 _amount) external onlyOwner
	{
		address _from = address(this);
		uint256 _balance = balanceOf(_from);
		_transfer(_from, _to, Math._min(_balance, _amount));
	}
}
