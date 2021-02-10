// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { BEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/BEP20.sol";

contract GPlainToken is BEP20
{
	constructor (string memory _name, string memory _symbol, uint8 _decimals, uint256 _initialSupply)
		BEP20(_name, _symbol) public
	{
		address _sender = msg.sender;
		require(_decimals == 18, "unsupported decimals");
		_mint(_sender, _initialSupply);
	}
}
