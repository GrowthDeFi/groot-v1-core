// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

import { GTokenRegistry } from "./GTokenRegistry.sol";
import { GNativeBridge } from "./GNativeBridge.sol";
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
	address constant GROOT_TREASURY = 0x0000000000000000000000000000000000000001; // TODO update this address

	uint256 constant GROOT_TOTAL_SUPPLY = 20000e18; // 20k
	uint256 constant GROOT_TREASURY_ALLOCATION = 9750e18; // 9,750
	uint256 constant GROOT_LIQUIDITY_ALLOCATION = 250e18; // 250
	uint256 constant GROOT_FARMING_ALLOCATION = 8000e18; // 8k
	uint256 constant GROOT_AIRDROP_ALLOCATION = 2000e18; // 2k

	uint256 constant SAFE_TOTAL_SUPPLY = 168675e18; // 168,675
	uint256 constant SAFE_AIRDROP_ALLOCATION = 168675e18; // 168,675

	uint256 constant WBNB_LIQUIDITY_ALLOCATION = 700e18; // 700

	struct Payment {
		address receiver;
		uint256 amount;
	}

	Payment[] public paymentsGROOT;
	Payment[] public paymentsSAFE;

	address public registry;
	address public bridge;
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

		// wraps BNB into WBNB
		Wrapping._wrap(WBNB_LIQUIDITY_ALLOCATION);

		// deploy contracts
		registry = LibDeployer1.publishGTokenRegistry();
		bridge = LibDeployer1.publishGNativeBridge();

		SAFE = LibDeployer1.publishSAFE(SAFE_TOTAL_SUPPLY);

		gROOT = LibDeployer2.publishGROOT(GROOT_TOTAL_SUPPLY);
		stkgROOT = LibDeployer2.publishSTKGROOT(gROOT);
		masterChef = LibDeployer3.publishMasterChef(gROOT, stkgROOT);

		// create LPs
		gROOT_WBNB = Factory($.PancakeSwap_FACTORY).createPair(gROOT, $.WBNB);
		MasterChef(masterChef).add(1000, IBEP20(gROOT_WBNB), false);

		// adds liquidity to LPs
		Transfers._pushFunds(gROOT, gROOT_WBNB, GROOT_LIQUIDITY_ALLOCATION);
		Transfers._pushFunds($.WBNB, gROOT_WBNB, WBNB_LIQUIDITY_ALLOCATION);
		uint256 _lpshares = Pair(gROOT_WBNB).mint(address(this));

		// create strategy contract and stake LP shares
		stkgROOT_BNB = LibDeployer4.publishSTKGROOTBNB(masterChef, 1);
		Transfers._approveFunds(gROOT_WBNB, stkgROOT_BNB, _lpshares);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).bootstrap();
		GRewardCompoundingStrategyToken(stkgROOT_BNB).deposit(_lpshares - 1);

		// transfer treasury and farming funds to the treasury
		Transfers._pushFunds(gROOT, GROOT_TREASURY, GROOT_TREASURY_ALLOCATION);
		Transfers._pushFunds(gROOT, GROOT_TREASURY, GROOT_FARMING_ALLOCATION);

		require(Transfers._getBalance(gROOT) == GROOT_AIRDROP_ALLOCATION, "gROOT amount mismatch");
		require(Transfers._getBalance(SAFE) == SAFE_AIRDROP_ALLOCATION, "SAFE amount mismatch");

		// register tokens
		GTokenRegistry(registry).registerNewToken(gROOT, address(0));
		GTokenRegistry(registry).registerNewToken(SAFE, address(0));
		GTokenRegistry(registry).registerNewToken(stkgROOT, address(0));

		// transfer ownerships
		Ownable(gROOT).transferOwnership(masterChef);
		Ownable(stkgROOT).transferOwnership(masterChef);

		Ownable(registry).transferOwnership(GROOT_TREASURY);
		Ownable(masterChef).transferOwnership(GROOT_TREASURY);
		Ownable(SAFE).transferOwnership(GROOT_TREASURY);

		// wrap up the deployment
		deployed = true;
		emit DeployPerformed();
	}

	function airdrop() external onlyOwner
	{
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

	function publishGNativeBridge() public returns (address _address)
	{
		return address(new GNativeBridge());
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
	function publishMasterChef(address _rewardToken, address _stkgROOT) public returns (address _address)
	{
		return address(new MasterChef(GRewardToken(_rewardToken), GRewardStakeToken(_stkgROOT), _rewardToken, 0, block.number));
	}
}

library LibDeployer4
{
	function publishSTKGROOTBNB(address _masterChef, uint256 _pid) public returns (address _address)
	{
		return address(new stkgROOT_BNB(_masterChef, _pid));
	}
}
