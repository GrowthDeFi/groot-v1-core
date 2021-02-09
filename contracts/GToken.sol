// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract GToken is ERC20, Ownable, ReentrancyGuard
{
	constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply)
		ERC20(_name, _symbol) public
	{
		address _sender = msg.sender;
		_setupDecimals(_decimals);
		_mint(_sender, _initialSupply);
	}
}
