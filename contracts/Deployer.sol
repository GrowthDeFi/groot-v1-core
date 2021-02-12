// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@pancakeswap/pancake-swap-lib/contracts/access/Ownable.sol";
import { IBEP20 } from "@pancakeswap/pancake-swap-lib/contracts/token/BEP20/IBEP20.sol";

import { GTokenRegistry } from "./GTokenRegistry.sol";
import { GNativeBridge } from "./GNativeBridge.sol";
import { GRewardToken } from "./GRewardToken.sol";
import { PMINE, SAFE } from "./GTokens.sol";

import { MasterChef } from "./MasterChef.sol";
import { SyrupBar } from "./SyrupBar.sol";

import { Transfers } from "./modules/Transfers.sol";

import { $ } from "./network/$.sol";

contract Deployer is Ownable
{
	address constant PMINE_TREASURY = 0x0000000000000000000000000000000000000001; // TODO update this address

	uint256 constant PMINE_TOTAL_SUPPLY = 20000e18; // 20k
	uint256 constant SAFE_TOTAL_SUPPLY = 168675e18; // 168,675

	uint256 constant PMINE_TREASURY_ALLOCATION = 10000e18; // 10k
	uint256 constant PMINE_FARMING_ALLOCATION = 8000e18; // 8k
	uint256 constant PMINE_SWAPPING_ALLOCATION = 2000e18; // 2k

	struct Payment {
		address receiver;
		uint256 amount;
	}

	Payment[] public paymentsPMINE;
	Payment[] public paymentsSAFE;

	address[] public contracts;

	bool public deployed = false;

	function registerReceiversPMINE(address[] memory _receivers, uint256[] memory _amounts) external onlyOwner
	{
		require(_receivers.length == _amounts.length, "length mismatch");
		for (uint256 _i = 0; _i < _receivers.length; _i++) {
			address _receiver = _receivers[_i];
			uint256 _amount = _amounts[_i];
			require(_amount > 0, "zero amount");
			paymentsPMINE.push(Payment({ receiver: _receiver, amount: _amount }));
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
		require($.NETWORK == $.network(), "wrong network");

		// deploy contracts
		address _registry = LibDeployer1.publishGTokenRegistry();
		address _bridge = LibDeployer1.publishGNativeBridge();

		address _PMINE = LibDeployer1.publishPMINE(PMINE_TOTAL_SUPPLY);
		address _SAFE = LibDeployer1.publishSAFE(SAFE_TOTAL_SUPPLY);

		address _syrupBar = LibDeployer2.publishSyrupBar(_PMINE);
		address _masterChef = LibDeployer3.publishMasterChef(_PMINE, _syrupBar);

		// transfer treasury and farming pools to the treasury
		IBEP20(_PMINE).transfer(PMINE_TREASURY, PMINE_TREASURY_ALLOCATION);

		IBEP20(_PMINE).transfer(PMINE_TREASURY, PMINE_FARMING_ALLOCATION);

		// airdrops PMINE
		for (uint256 _i = 0; _i < paymentsPMINE.length; _i++) {
			Payment storage _payment = paymentsPMINE[_i];
			IBEP20(_PMINE).transfer(_payment.receiver, _payment.amount);
		}

		// ardrops SAFE
		for (uint256 _i = 0; _i < paymentsSAFE.length; _i++) {
			Payment storage _payment = paymentsSAFE[_i];
			IBEP20(_SAFE).transfer(_payment.receiver, _payment.amount);
		}

		require(Transfers._getBalance(_PMINE) == 0, "PMINE left over");
		require(Transfers._getBalance(_SAFE) == 0, "SAFE left over");

		// register tokens
		GTokenRegistry(_registry).registerNewToken(_PMINE, address(0));
		GTokenRegistry(_registry).registerNewToken(_SAFE, address(0));
		GTokenRegistry(_registry).registerNewToken(_syrupBar, address(0));

		// transfer ownerships
		GTokenRegistry(_registry).transferOwnership(PMINE_TREASURY);
		PMINE(_PMINE).transferOwnership(_masterChef);
		SAFE(_SAFE).transferOwnership(PMINE_TREASURY);
		SyrupBar(_syrupBar).transferOwnership(_masterChef);
		MasterChef(_masterChef).transferOwnership(PMINE_TREASURY);

		// make contract addresses visible
		contracts.push(_registry);
		contracts.push(_bridge);
		contracts.push(_PMINE);
		contracts.push(_SAFE);
		contracts.push(_syrupBar);
		contracts.push(_masterChef);

		// wrap up the deployment
		deployed = true;
		renounceOwnership();
		emit DeployPerformed();
	}

	event DeployPerformed();
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

	function publishPMINE(uint256 _totalSupply) public returns (address _address)
	{
		return address(new PMINE(_totalSupply));
	}

	function publishSAFE(uint256 _totalSupply) public returns (address _address)
	{
		return address(new SAFE(_totalSupply));
	}
}

library LibDeployer2
{
	function publishSyrupBar(address _rewardToken) public returns (address _address)
	{
		return address(new SyrupBar(GRewardToken(_rewardToken)));
	}
}

library LibDeployer3
{
	function publishMasterChef(address _rewardToken, address _syrup) public returns (address _address)
	{
		return address(new MasterChef(GRewardToken(_rewardToken), SyrupBar(_syrup), _rewardToken, 0, block.number));
	}
}
