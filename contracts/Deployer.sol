// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

import { GTokenRegistry } from "./GTokenRegistry.sol";
import { GNativeBridge } from "./GNativeBridge.sol";
import { GRewardToken } from "./GRewardToken.sol";
import { GRewardStakeToken } from "./GRewardStakeToken.sol";
import { gROOT, stkgROOT, SAFE } from "./GTokens.sol";
import { MasterChef } from "./MasterChef.sol";

import { Transfers } from "./modules/Transfers.sol";

import { $ } from "./network/$.sol";

contract Deployer is Ownable
{
	address constant GROOT_TREASURY = 0x0000000000000000000000000000000000000001; // TODO update this address

	uint256 constant GROOT_TOTAL_SUPPLY = 20000e18; // 20k
	uint256 constant GROOT_TREASURY_ALLOCATION = 10000e18; // 10k
	uint256 constant GROOT_FARMING_ALLOCATION = 8000e18; // 8k
	uint256 constant GROOT_AIRDROP_ALLOCATION = 2000e18; // 2k

	uint256 constant SAFE_TOTAL_SUPPLY = 168675e18; // 168,675
	uint256 constant SAFE_AIRDROP_ALLOCATION = 168675e18; // 168,675

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

	function deploy() external onlyOwner
	{
		require(!deployed, "deploy unavailable");

		// deploy contracts
		registry = LibDeployer1.publishGTokenRegistry();
		bridge = LibDeployer1.publishGNativeBridge();

		SAFE = LibDeployer1.publishSAFE(SAFE_TOTAL_SUPPLY);

		gROOT = LibDeployer2.publishGROOT(GROOT_TOTAL_SUPPLY);
		stkgROOT = LibDeployer2.publishSTKGROOT(gROOT);
		masterChef = LibDeployer3.publishMasterChef(gROOT, stkgROOT);

		// transfer treasury and farming pools to the treasury
		IBEP20(gROOT).transfer(GROOT_TREASURY, GROOT_TREASURY_ALLOCATION);

		IBEP20(gROOT).transfer(GROOT_TREASURY, GROOT_FARMING_ALLOCATION);

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
			IBEP20(gROOT).transfer(_payment.receiver, _payment.amount);
		}

		// ardrops SAFE
		for (uint256 _i = 0; _i < paymentsSAFE.length; _i++) {
			Payment storage _payment = paymentsSAFE[_i];
			IBEP20(SAFE).transfer(_payment.receiver, _payment.amount);
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
