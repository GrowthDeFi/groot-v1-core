// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev Custom and uniform interface to a decentralized exchange. It is used
 *      to estimate and convert funds whenever necessary. This furnishes
 *      client contracts with the flexibility to replace conversion strategy
 *      and routing, dynamically, by delegating these operations to different
 *      external contracts that share this common interface. See
 *      GExchangeImpl.sol for further documentation.
 */
interface GExchange
{
	// view functions
	function calcConversionFromInput(address _from, address _to, uint256 _inputAmount) external view returns (uint256 _outputAmount);
	function calcConversionFromOutput(address _from, address _to, uint256 _outputAmount) external view returns (uint256 _inputAmount);

	// open functions
	function convertFundsFromInput(address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) external returns (uint256 _outputAmount);
	function convertFundsFromOutput(address _from, address _to, uint256 _outputAmount, uint256 _maxInputAmount) external returns (uint256 _inputAmount);
}
