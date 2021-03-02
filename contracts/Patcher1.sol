// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Deployer } from "./Deployer.sol";
import { GTokenRegistry } from "./GTokenRegistry.sol";
import { GRewardHolder } from "./GRewardHolder.sol";
import { GRewardToken } from "./GRewardToken.sol";
import { GRewardStakeToken } from "./GRewardStakeToken.sol";
import { GRewardCompoundingStrategyToken } from "./GRewardCompoundingStrategyToken.sol";
import { stkgROOT, SAFE, stkgROOT_BNB } from "./GTokens.sol";
import { MasterChef } from "./MasterChef.sol";

import { $ } from "./network/$.sol";

contract Patcher1 is Ownable
{
	address constant GROOT_DEFAULT_FEE_COLLECTOR = 0xB0632a01ee778E09625BcE2a257e221b49E79696;

	address constant GROOT_CONTRACTS_OWNER = 0xBf70B751BB1FC725bFbC4e68C4Ec4825708766c5;

	uint256 constant INITIAL_GROOT_PER_BLOCK = 0e18; // 0

	uint256 public rewardStartBlock;
	address public holder;
	address public stkgROOT;
	address public masterChef;
	address public stkgROOT_BNB;

	bool public patched = false;

	constructor () public
	{
		require($.NETWORK == $.network(), "wrong network");
	}

	function patch(address _deployer) external onlyOwner
	{
		require(!patched, "patch unavailable");

		// initialize handy fields
		// address _registry = Deployer(_deployer).registry();
		address _exchange = Deployer(_deployer).exchange();
		address _gROOT = Deployer(_deployer).gROOT();
		address _gROOT_WBNB = Deployer(_deployer).gROOT_WBNB();

		// deploy new MasterChef for reward distribution
		rewardStartBlock = block.number;
		holder = LibPatcher1.publishGRewardHolder(_gROOT);
		stkgROOT = LibPatcher1.publishSTKGROOT(_gROOT);
		masterChef = LibPatcher2.publishMasterChef(_gROOT, stkgROOT, holder, INITIAL_GROOT_PER_BLOCK, rewardStartBlock);

		// create gROOT/BNB LP and register it for reward distribution
		MasterChef(masterChef).setHolder(GRewardHolder(holder));
		MasterChef(masterChef).add(1000, IERC20(_gROOT_WBNB), false);

		// create and configure compounding strategy contract for gROOT/BNB
		stkgROOT_BNB = LibPatcher3.publishSTKGROOTBNB(masterChef, 1, _gROOT);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setExchange(_exchange);
		GRewardCompoundingStrategyToken(stkgROOT_BNB).setTreasury(GROOT_DEFAULT_FEE_COLLECTOR);

		// register tokens (needs to be performed manually)
		// GTokenRegistry(_registry).registerNewToken(stkgROOT, Deployer(_deployer).stkgROOT());
		// GTokenRegistry(_registry).registerNewToken(stkgROOT_BNB, Deployer(_deployer).stkgROOT_BNB());

		// transfer ownerships
		Ownable(holder).transferOwnership(masterChef);
		Ownable(stkgROOT).transferOwnership(masterChef);

		Ownable(masterChef).transferOwnership(GROOT_CONTRACTS_OWNER);
		Ownable(stkgROOT_BNB).transferOwnership(GROOT_CONTRACTS_OWNER);

		// wrap up the deployment
		renounceOwnership();
		patched = true;
		emit PatchPerformed();
	}

	event PatchPerformed();
}

library LibPatcher1
{
	function publishGRewardHolder(address _rewardToken) public returns (address _address)
	{
		return address(new GRewardHolder(_rewardToken));
	}

	function publishSTKGROOT(address _rewardToken) public returns (address _address)
	{
		return address(new stkgROOT(_rewardToken));
	}
}

library LibPatcher2
{
	function publishMasterChef(address _rewardToken, address _rewardStakeToken, address _devAddress, uint256 _rewardPerBlock, uint256 _rewardStartBlock) public returns (address _address)
	{
		return address(new MasterChef(GRewardToken(_rewardToken), GRewardStakeToken(_rewardStakeToken), _devAddress, _rewardPerBlock, _rewardStartBlock));
	}
}

library LibPatcher3
{
	function publishSTKGROOTBNB(address _masterChef, uint256 _pid, address _routingToken) public returns (address _address)
	{
		return address(new stkgROOT_BNB(_masterChef, _pid, _routingToken));
	}
}
