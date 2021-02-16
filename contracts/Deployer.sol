// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

import { GTokenRegistry } from "./GTokenRegistry.sol";
import { GExchangeImpl } from "./GExchangeImpl.sol";
import { GRewardToken } from "./GRewardToken.sol";
import { GRewardStakeToken } from "./GRewardStakeToken.sol";
import { GRewardCompoundingStrategyToken } from "./GRewardCompoundingStrategyToken.sol";
import { gROOT, stkgROOT, SAFE, stkgROOT_BNB } from "./GTokens.sol";
import { MasterChef } from "./MasterChef.sol";

import { Factory, Pair } from "./interop/PancakeSwap.sol";

import { Transfers } from "./modules/Transfers.sol";
import { Wrapping } from "./modules/Wrapping.sol";

import { $ } from "./network/$.sol";

contract Deployer is Ownable
{
	address constant GROOT_TREASURY = 0xC4faC8CA576B9c8B971fA36916aEE062d84b4901; // TODO update this address

	uint256 constant GROOT_TOTAL_SUPPLY = 20000e18; // 20,000
	uint256 constant GROOT_TREASURY_ALLOCATION = 9750e18; // 9,750
	uint256 constant GROOT_LIQUIDITY_ALLOCATION = 250e18; // 250
	uint256 constant GROOT_FARMING_ALLOCATION = 7999e18; // 7,999
	uint256 constant GROOT_INITIAL_FARMING_ALLOCATION = 1e18; // 1
	uint256 constant GROOT_AIRDROP_ALLOCATION = 2000e18; // 2,000

	uint256 constant SAFE_TOTAL_SUPPLY = 168675e18; // 168,675
	uint256 constant SAFE_AIRDROP_ALLOCATION = 168675e18; // 168,675

	uint256 constant WBNB_LIQUIDITY_ALLOCATION = 700e18; // 700

	uint256 constant AVERAGE_BLOCK_TIME = 3 seconds;
	uint256 constant INITIAL_GROOT_PER_MONTH = 150e18; // 150
	uint256 constant INITIAL_GROOT_PER_BLOCK = AVERAGE_BLOCK_TIME * INITIAL_GROOT_PER_MONTH / 30 days;

	struct Payment {
		address receiver;
		uint256 amount;
	}

	Payment[] public paymentsGROOT;
	Payment[] public paymentsSAFE;

	uint256 public rewardStartBlock;
	address public pancakeSwapRouter;
	address public registry;
	address public exchange;
	address public SAFE;
	address public gROOT;
	address public stkgROOT;
	address public masterChef;
	address public gROOT_WBNB;
	address public stkgROOT_BNB;

	bool public deployed = false;
	bool public airdropped = false;

	constructor () public
	{
		require($.NETWORK == $.network(), "wrong network");
	}

	function registerReceiversGROOT(address[] memory _receivers, uint256[] memory _amounts) external onlyOwner
	{
		require(_receivers.length == _amounts.length, "length mismatch");
		for (uint256 _i = 0; _i < _receivers.length; _i++) {
			address _receiver = _receivers[_i];
			uint256 _amount = _amounts[_i];
			require(_amount > 0, "zero amount");
			paymentsGROOT.push(Payment({ receiver: _receiver, amount: _amount }));
		}
	}

	function registerReceiversSAFE(address[] memory _receivers, uint256[] memory _amounts) external onlyOwner
	{
		require(_receivers.length == _amounts.length, "length mismatch");
		for (uint256 _i = 0; _i < _receivers.length; _i++) {
			address _receiver = _receivers[_i];
			uint256 _amount = _amounts[_i];
			require(_amount > 0, "zero amount");
			paymentsSAFE.push(Payment({ receiver: _receiver, amount: _amount }));
		}
	}

	function deploy() payable external onlyOwner
	{
		uint256 _amount = msg.value;
		require(_amount == WBNB_LIQUIDITY_ALLOCATION, "BNB amount mismatch");

		require(!deployed, "deploy unavailable");

		// wraps LP liquidity BNB into WBNB
		Wrapping._wrap(WBNB_LIQUIDITY_ALLOCATION);

		// initialize handy fields
		rewardStartBlock = block.number;
		pancakeSwapRouter = $.PancakeSwap_ROUTER02;

		// deploy helper contracts
		registry = LibDeployer1.publishGTokenRegistry();
		exchange = LibDeployer1.publishGExchangeImpl(pancakeSwapRouter);

		// deploy SAFE token
		SAFE = LibDeployer1.publishSAFE(SAFE_TOTAL_SUPPLY);

		// deploy gROOT token and MasterChef for reward distribution
		gROOT = LibDeployer2.publishGROOT(GROOT_TOTAL_SUPPLY);
		stkgROOT = LibDeployer2.publishSTKGROOT(gROOT);
		masterChef = LibDeployer3.publishMasterChef(gROOT, stkgROOT, INITIAL_GROOT_PER_BLOCK, rewardStartBlock);
		GRewardToken(gROOT).allocateReward(GROOT_INITIAL_FARMING_ALLOCATION);

		// create gROOT/BNB LP and register it for reward distribution
		gROOT_WBNB = Factory($.PancakeSwap_FACTORY).createPair(gROOT, $.WBNB);
		MasterChef(masterChef).add(1000, IBEP20(gROOT_WBNB), false);

		// adds the liquidity to the gROOT/BNB LP
		Transfers._pushFunds(gROOT, gROOT_WBNB, GROOT_LIQUIDITY_ALLOCATION);
		Transfers._pushFunds($.WBNB, gROOT_WBNB, WBNB_LIQUIDITY_ALLOCATION);
		uint256 _lpshares = Pair(gROOT_WBNB).mint(address(this));

		// create and configure compounding strategy contract for gROOT/BNB
		stkgROOT_BNB = LibDeployer4.publishSTKGROOTBNB(masterChef, 1, gROOT);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setExchange(exchange);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setTreasury(GROOT_TREASURY);

		// stake gROOT/BNB LP shares into strategy contract
		Transfers._approveFunds(gROOT_WBNB, stkgROOT_BNB, _lpshares);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).deposit(_lpshares);
		Transfers._pushFunds(stkgROOT_BNB, GROOT_TREASURY, _lpshares);

		// transfer treasury and farming funds to the treasury
		Transfers._pushFunds(gROOT, GROOT_TREASURY, GROOT_TREASURY_ALLOCATION);
		Transfers._pushFunds(gROOT, GROOT_TREASURY, GROOT_FARMING_ALLOCATION);

		require(Transfers._getBalance(gROOT) == GROOT_AIRDROP_ALLOCATION, "gROOT amount mismatch");
		require(Transfers._getBalance(SAFE) == SAFE_AIRDROP_ALLOCATION, "SAFE amount mismatch");

		// register tokens
		GTokenRegistry(registry).registerNewToken(SAFE, address(0));
		GTokenRegistry(registry).registerNewToken(gROOT, address(0));
		GTokenRegistry(registry).registerNewToken(stkgROOT, address(0));
		GTokenRegistry(registry).registerNewToken(stkgROOT_BNB, address(0));

		// transfer ownerships
		Ownable(gROOT).transferOwnership(masterChef);
		Ownable(stkgROOT).transferOwnership(masterChef);

		Ownable(registry).transferOwnership(GROOT_TREASURY);
		Ownable(SAFE).transferOwnership(GROOT_TREASURY);
		Ownable(masterChef).transferOwnership(GROOT_TREASURY);
		Ownable(stkgROOT_BNB).transferOwnership(GROOT_TREASURY);

		// wrap up the deployment
		deployed = true;
		emit DeployPerformed();
	}

	function airdrop() external onlyOwner
	{
		require(deployed, "airdrop unavailable");
		require(!airdropped, "airdrop unavailable");

		require(Transfers._getBalance(gROOT) == GROOT_AIRDROP_ALLOCATION, "gROOT amount mismatch");
		require(Transfers._getBalance(SAFE) == SAFE_AIRDROP_ALLOCATION, "SAFE amount mismatch");

		// airdrops gROOT
		for (uint256 _i = 0; _i < paymentsGROOT.length; _i++) {
			Payment storage _payment = paymentsGROOT[_i];
			Transfers._pushFunds(gROOT, _payment.receiver, _payment.amount);
		}

		// ardrops SAFE
		for (uint256 _i = 0; _i < paymentsSAFE.length; _i++) {
			Payment storage _payment = paymentsSAFE[_i];
			Transfers._pushFunds(SAFE, _payment.receiver, _payment.amount);
		}

		require(Transfers._getBalance(gROOT) == 0, "gROOT left over");
		require(Transfers._getBalance(SAFE) == 0, "SAFE left over");

		renounceOwnership();

		airdropped = true;
		emit AirdropPerformed();
	}

	event DeployPerformed();
	event AirdropPerformed();
}

library LibDeployer1
{
	function publishGTokenRegistry() public returns (address _address)
	{
		return address(new GTokenRegistry());
	}

	function publishGExchangeImpl(address _router) public returns (address _address)
	{
		return address(new GExchangeImpl(_router));
	}

	function publishSAFE(uint256 _totalSupply) public returns (address _address)
	{
		return address(new SAFE(_totalSupply));
	}
}

library LibDeployer2
{
	function publishGROOT(uint256 _totalSupply) public returns (address _address)
	{
		return address(new gROOT(_totalSupply));
	}

	function publishSTKGROOT(address _rewardToken) public returns (address _address)
	{
		return address(new stkgROOT(_rewardToken));
	}
}

library LibDeployer3
{
	function publishMasterChef(address _rewardToken, address _rewardStakeToken, uint256 _rewardPerBlock, uint256 _rewardStartBlock) public returns (address _address)
	{
		return address(new MasterChef(GRewardToken(_rewardToken), GRewardStakeToken(_rewardStakeToken), _rewardToken, _rewardPerBlock, _rewardStartBlock));
	}
}

library LibDeployer4
{
	function publishSTKGROOTBNB(address _masterChef, uint256 _pid, address _routingToken) public returns (address _address)
	{
		return address(new stkgROOT_BNB(_masterChef, _pid, _routingToken));
	}
}
