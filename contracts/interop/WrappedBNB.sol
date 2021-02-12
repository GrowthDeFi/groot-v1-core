// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

/**
 * @dev Minimal set of declarations for WBNB interoperability.
 */
interface WBNB is IBEP20
{
	function deposit() external payable;
	function withdraw(uint256 _amount) external;
}
