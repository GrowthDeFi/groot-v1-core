// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { GExchange } from "./GExchange.sol";

import { Transfers } from "./modules/Transfers.sol";
import { PancakeSwapExchangeAbstraction } from "./modules/PancakeSwapExchangeAbstraction.sol";

/**
 * @notice This contract implements the GExchange interface routing token
 *         conversions via a Uniswap V2 compatible exchange.
 */
contract GExchangeImpl is GExchange
{
	address public immutable router;

	constructor (address _router)
		public
	{
		router = _router;
	}

	/**
	 * @notice Computes the amount of tokens to be received upon conversion.
	 * @param _from The contract address of the ERC-20 token to convert from.
	 * @param _to The contract address of the ERC-20 token to convert to.
	 * @param _inputAmount The amount of the _from token to be provided (may be 0).
	 * @return _outputAmount The amount of the _to token to be received (may be 0).
	 */
	function calcConversionFromInput(address _from, address _to, uint256 _inputAmount) external view override returns (uint256 _outputAmount)
	{
		return PancakeSwapExchangeAbstraction._calcConversionFromInput(router, _from, _to, _inputAmount);
	}

	/**
	 * @notice Computes the amount of tokens to be provided upon conversion.
	 * @param _from The contract address of the ERC-20 token to convert from.
	 * @param _to The contract address of the ERC-20 token to convert to.
	 * @param _outputAmount The amount of the _to token to be received (may be 0).
	 * @return _inputAmount The amount of the _from token to be provided (may be 0).
	 */
	function calcConversionFromOutput(address _from, address _to, uint256 _outputAmount) external view override returns (uint256 _inputAmount)
	{
		return PancakeSwapExchangeAbstraction._calcConversionFromOutput(router, _from, _to, _outputAmount);
	}

	/**
	 * @notice Converts a given token amount to another token, as long as it
	 *         meets the minimum taken amount. Amounts are debited from and
	 *         and credited to the caller contract. It may fail if the
	 *         minimum output amount cannot be met.
	 * @param _from The contract address of the ERC-20 token to convert from.
	 * @param _to The contract address of the ERC-20 token to convert to.
	 * @param _inputAmount The amount of the _from token to be provided (may be 0).
	 * @param _minOutputAmount The minimum amount of the _to token to be received (may be 0).
	 * @return _outputAmount The actual amount of the _to token received (may be 0).
	 */
	function convertFundsFromInput(address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) external override returns (uint256 _outputAmount)
	{
		address _sender = msg.sender;
		Transfers._pullFunds(_from, _sender, _inputAmount);
		_outputAmount = PancakeSwapExchangeAbstraction._convertFundsFromInput(router, _from, _to, _inputAmount, _minOutputAmount);
		Transfers._pushFunds(_to, _sender, _outputAmount);
		return _outputAmount;
	}

	/**
	 * @notice Converts a given token amount to another token, as long as it
	 *         meets the maximum given amount. Amounts are debited from and
	 *         and credited to the caller contract. It may fail if the
	 *         maximum input amount cannot be met.
	 * @param _from The contract address of the ERC-20 token to convert from.
	 * @param _to The contract address of the ERC-20 token to convert to.
	 * @param _outputAmount The amount of the _to token to be received (may be 0).
	 * @param _maxInputAmount The maximum amount of the _from token to be provided (may be 0).
	 * @return _inputAmount The actual amount of the _from token provided (may be 0).
	 */
	function convertFundsFromOutput(address _from, address _to, uint256 _outputAmount, uint256 _maxInputAmount) external override returns (uint256 _inputAmount)
	{
		address _sender = msg.sender;
		Transfers._pullFunds(_from, _sender, _maxInputAmount);
		_inputAmount = PancakeSwapExchangeAbstraction._convertFundsFromOutput(router, _from, _to, _outputAmount, _maxInputAmount);
		Transfers._pushFunds(_from, _sender, _maxInputAmount - _inputAmount);
		Transfers._pushFunds(_to, _sender, _outputAmount);
		return _inputAmount;
	}
}
