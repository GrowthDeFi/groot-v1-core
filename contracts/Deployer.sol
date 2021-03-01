// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
	address constant GROOT_TREASURY1 = 0x2165fa4a32B9c228cD55713f77d2e977297D03e8; // G
	address constant GROOT_TREASURY2 = 0x6248f5783A1F908F7fbB651bb3Ca27BF7c9f5022; // M
	address constant GROOT_TREASURY3 = 0xBf70B751BB1FC725bFbC4e68C4Ec4825708766c5; // S

	address constant GROOT_INITIAL_STAKE_HOLDER = 0x5c327D395D0617f5b6ad6E8Da5dCBb35A6Be5b11;
	address constant GROOT_DEFAULT_FEE_COLLECTOR = 0xB0632a01ee778E09625BcE2a257e221b49E79696;

	address constant GROOT_CONTRACTS_OWNER = 0xBf70B751BB1FC725bFbC4e68C4Ec4825708766c5;

	uint256 constant GROOT_TOTAL_SUPPLY = 20000e18; // 20,000
	uint256 constant GROOT_TREASURY_ALLOCATION = 10430e18; // 10,430
	uint256 constant GROOT_LIQUIDITY_ALLOCATION = 70e18; // 70
	uint256 constant GROOT_FARMING_ALLOCATION = 8000e18; // 8,000
	uint256 constant GROOT_INITIAL_FARMING_ALLOCATION = 0e18; // 0
	uint256 constant GROOT_AIRDROP_ALLOCATION = 1500e18; // 1,500

	uint256 constant SAFE_TOTAL_SUPPLY = 168675e18; // 168,675
	uint256 constant SAFE_AIRDROP_ALLOCATION = 168675e18; // 168,675

	uint256 constant WBNB_LIQUIDITY_ALLOCATION = 300e18; // 300

	uint256 constant AVERAGE_BLOCK_TIME = 3 seconds;
	uint256 constant INITIAL_GROOT_PER_MONTH = 0e18; // 0
	uint256 constant INITIAL_GROOT_PER_BLOCK = AVERAGE_BLOCK_TIME * INITIAL_GROOT_PER_MONTH / 30 days;

	bool constant STAKE_LP_SHARES = false;

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
		// GRewardToken(gROOT).allocateReward(GROOT_INITIAL_FARMING_ALLOCATION);

		// create gROOT/BNB LP and register it for reward distribution
		gROOT_WBNB = Factory($.PancakeSwap_FACTORY).createPair(gROOT, $.WBNB);
		MasterChef(masterChef).add(1000, IERC20(gROOT_WBNB), false);

		// adds the liquidity to the gROOT/BNB LP
		Transfers._pushFunds(gROOT, gROOT_WBNB, GROOT_LIQUIDITY_ALLOCATION);
		Transfers._pushFunds($.WBNB, gROOT_WBNB, WBNB_LIQUIDITY_ALLOCATION);
		uint256 _lpshares = Pair(gROOT_WBNB).mint(address(this));

		// create and configure compounding strategy contract for gROOT/BNB
		stkgROOT_BNB = LibDeployer4.publishSTKGROOTBNB(masterChef, 1, gROOT);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setExchange(exchange);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setTreasury(GROOT_DEFAULT_FEE_COLLECTOR);

		// stake gROOT/BNB LP shares into strategy contract
		if (STAKE_LP_SHARES) {
			Transfers._approveFunds(gROOT_WBNB, stkgROOT_BNB, _lpshares);
			GRewardCompoundingStrategyToken(stkgROOT_BNB).deposit(_lpshares);
			Transfers._pushFunds(stkgROOT_BNB, GROOT_INITIAL_STAKE_HOLDER, _lpshares);
		} else {
			Transfers._pushFunds(gROOT_WBNB, GROOT_INITIAL_STAKE_HOLDER, _lpshares);
		}

		// transfer treasury funds to the treasury
		Transfers._pushFunds(gROOT, GROOT_TREASURY1, GROOT_TREASURY_ALLOCATION / 3);
		Transfers._pushFunds(gROOT, GROOT_TREASURY2, GROOT_TREASURY_ALLOCATION / 3);
		Transfers._pushFunds(gROOT, GROOT_TREASURY3, GROOT_TREASURY_ALLOCATION - 2 * (GROOT_TREASURY_ALLOCATION / 3));

		// transfer farming funds to the treasury
		Transfers._pushFunds(gROOT, GROOT_TREASURY1, GROOT_FARMING_ALLOCATION / 3);
		Transfers._pushFunds(gROOT, GROOT_TREASURY2, GROOT_FARMING_ALLOCATION / 3);
		Transfers._pushFunds(gROOT, GROOT_TREASURY3, GROOT_FARMING_ALLOCATION - 2 * (GROOT_FARMING_ALLOCATION / 3));

		require(Transfers._getBalance($.WBNB) == 0, "WBNB left over");
		require(Transfers._getBalance(gROOT_WBNB) == 0, "gROOT_WBNB left over");
		require(Transfers._getBalance(stkgROOT_BNB) == 0, "stkgROOT_BNB left over");
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

		Ownable(registry).transferOwnership(GROOT_CONTRACTS_OWNER);
		Ownable(SAFE).transferOwnership(GROOT_CONTRACTS_OWNER);
		Ownable(masterChef).transferOwnership(GROOT_CONTRACTS_OWNER);
		Ownable(stkgROOT_BNB).transferOwnership(GROOT_CONTRACTS_OWNER);

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
