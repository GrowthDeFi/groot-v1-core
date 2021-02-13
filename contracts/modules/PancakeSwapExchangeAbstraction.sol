// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Transfers } from "./Transfers.sol";

import { Router02 } from "../interop/PancakeSwap.sol";

/**
 * @dev This library abstracts the Uniswap V2 token exchange functionality.
 */
library PancakeSwapExchangeAbstraction
{
	/**
	 * @dev Calculates how much output to be received from the given input
	 *      when converting between two assets.
	 * @param _from The input asset address.
	 * @param _to The output asset address.
	 * @param _inputAmount The input asset amount to be provided.
	 * @return _outputAmount The output asset amount to be received.
	 */
	function _calcConversionFromInput(address _router, address _from, address _to, uint256 _inputAmount) internal view returns (uint256 _outputAmount)
	{
		address _WBNB = Router02(_router).WETH();
		address[] memory _path = _buildPath(_from, _WBNB, _to);
		return Router02(_router).getAmountsOut(_inputAmount, _path)[_path.length - 1];
	}

	/**
	 * @dev Calculates how much input to be received the given the output
	 *      when converting between two assets.
	 * @param _from The input asset address.
	 * @param _to The output asset address.
	 * @param _outputAmount The output asset amount to be received.
	 * @return _inputAmount The input asset amount to be provided.
	 */
	function _calcConversionFromOutput(address _router, address _from, address _to, uint256 _outputAmount) internal view returns (uint256 _inputAmount)
	{
		address _WBNB = Router02(_router).WETH();
		address[] memory _path = _buildPath(_from, _WBNB, _to);
		return Router02(_router).getAmountsIn(_outputAmount, _path)[0];
	}

	/**
	 * @dev Convert funds between two assets given the desired input amount.
	 * @param _from The input asset address.
	 * @param _to The output asset address.
	 * @param _inputAmount The exact input asset amount to be provided.
	 * @param _minOutputAmount The output asset minimum amount to be received.
	 * @return _outputAmount The output asset amount actually received.
	 */
	function _convertFundsFromInput(address _router, address _from, address _to, uint256 _inputAmount, uint256 _minOutputAmount) internal returns (uint256 _outputAmount)
	{
		address _WBNB = Router02(_router).WETH();
		address[] memory _path = _buildPath(_from, _WBNB, _to);
		Transfers._approveFunds(_from, _router, _inputAmount);
		return Router02(_router).swapExactTokensForTokens(_inputAmount, _minOutputAmount, _path, address(this), uint256(-1))[_path.length - 1];
	}

	/**
	 * @dev Convert funds between two assets given the desired output amount.
	 * @param _from The input asset address.
	 * @param _to The output asset address.
	 * @param _outputAmount The exact output asset amount to be received.
	 * @param _maxInputAmount The input asset maximum amount to be provided.
	 * @return _inputAmount The input asset amount actually provided.
	 */
	function _convertFundsFromOutput(address _router, address _from, address _to, uint256 _outputAmount, uint256 _maxInputAmount) internal returns (uint256 _inputAmount)
	{
		address _WBNB = Router02(_router).WETH();
		address[] memory _path = _buildPath(_from, _WBNB, _to);
		Transfers._approveFunds(_from, _router, _maxInputAmount);
		_inputAmount = Router02(_router).swapTokensForExactTokens(_outputAmount, _maxInputAmount, _path, address(this), uint256(-1))[0];
		Transfers._approveFunds(_from, _router, 0);
		return _inputAmount;
	}

	/**
	 * @dev Builds a routing path for conversion possibly using a thrid
	 *      token (likely WETH) as intermediate.
	 * @param _from The input asset address.
	 * @param _through The intermediate asset address.
	 * @param _to The output asset address.
	 * @return _path The route to perform conversion.
	 */
	function _buildPath(address _from, address _through, address _to) private pure returns (address[] memory _path)
	{
		assert(_from != _to);
		if (_from == _through || _to == _through) {
			_path = new address[](2);
			_path[0] = _from;
			_path[1] = _to;
			return _path;
		} else {
			_path = new address[](3);
			_path[0] = _from;
			_path[1] = _through;
			_path[2] = _to;
			return _path;
		}
	}
}
