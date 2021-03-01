// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Assert } from "truffle/Assert.sol";

import { Env } from "./Env.sol";

import { Factory } from "../contracts/interop/PancakeSwap.sol";

import { PancakeSwapLiquidityPoolAbstraction } from "../contracts/modules/PancakeSwapLiquidityPoolAbstraction.sol";

import { $ } from "../contracts/network/$.sol";

contract TestPancakeSwapLiquidityPoolAbstraction is Env
{
	function test01() external
	{
		_testPool($.WBNB, $.ETH, 1e8);
	}

	function test02() external
	{
		_testPool($.ETH, $.WBNB, 1e8);
	}

	function _testPool(address _source, address _target, uint256 _sourceAmount) private
	{
		address _pair = Factory($.PancakeSwap_FACTORY).getPair(_source, _target);

		_burnAll(_pair);
		_burnAll(_source);
		_burnAll(_target);
		_mint(_source, _sourceAmount);

		Assert.equal(_getBalance(_pair), 0, "Pair balance must be zero");
		Assert.equal(_getBalance(_source), _sourceAmount, "Source balance must match source amount");
		Assert.equal(_getBalance(_target), 0, "Target balance must be zero");

		uint256 _estimatedShares = PancakeSwapLiquidityPoolAbstraction._estimateJoinPool(_pair, _source, _sourceAmount);
		uint256 _shares = PancakeSwapLiquidityPoolAbstraction._joinPool(_pair, _source, _sourceAmount);

		// Assert.isAtLeast(_shares, _estimatedShares.sub(10), "Shares received must be at least estimate minus 10 wei");
		// Assert.isAtMost(_shares, _estimatedShares.add(10), "Shares received must be at most estimate plus 10 wei");

		Assert.equal(_getBalance(_pair), _shares, "Pair balance must match shares");
		// Assert.isAtMost(_getBalance(_source), 10, "Source balance must be at most 10 wei");
		// Assert.equal(_getBalance(_target), 0, "Target balance must be zero");

		_burnAll(_source);
		_burnAll(_target);

		uint256 _estimatedAmount = PancakeSwapLiquidityPoolAbstraction._estimateExitPool(_pair, _target, _shares);
		uint256 _targetAmount = PancakeSwapLiquidityPoolAbstraction._exitPool(_pair, _target, _shares);
		
		Assert.equal(_targetAmount, _estimatedAmount, "Amount received must match estimate");

		Assert.equal(_getBalance(_pair), 0, "Pair balance must be zero");
		Assert.equal(_getBalance(_source), 0, "Source balance must be zero");
		Assert.equal(_getBalance(_target), _targetAmount, "Target balance must match target amount");
	}
}
