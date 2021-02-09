// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract GPlainToken is ERC20
{
	constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply)
		ERC20(_name, _symbol) public
	{
		address _sender = msg.sender;
		_setupDecimals(_decimals);
		_mint(_sender, _initialSupply);
	}
}
