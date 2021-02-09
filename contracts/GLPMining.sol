// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

/**
 * @dev This interface exposes the base functionality of GLPMiningToken.
 */
interface GLPMining
{
	// view functions
	function reserveToken() external view returns (address _reserveToken);
	function rewardsToken() external view returns (address _rewardsToken);
	function treasury() external view returns (address _treasury);
	function performanceFee() external view returns (uint256 _performanceFee);
	function rewardPerBlock() external view returns (uint256 _rewardPerBlock);
	function calcSharesFromCost(uint256 _cost) external view returns (uint256 _shares);
	function calcCostFromShares(uint256 _shares) external view returns (uint256 _cost);
	function calcSharesFromTokenAmount(address _token, uint256 _amount) external view returns (uint256 _shares);
	function calcTokenAmountFromShares(address _token, uint256 _shares) external view returns (uint256 _amount);
	function totalReserve() external view returns (uint256 _totalReserve);
	function rewardInfo() external view returns (uint256 _lockedReward, uint256 _unlockedReward);
	function pendingFees() external view returns (uint256 _feeShares);

	// open functions
	function deposit(uint256 _cost) external;
	function withdraw(uint256 _shares) external;
	function depositToken(address _token, uint256 _amount, uint256 _minShares) external;
	function withdrawToken(address _token, uint256 _shares, uint256 _minAmount) external;
	function gulpRewards(uint256 _minCost) external;
	function gulpFees() external;

	// priviledged functions
	function setTreasury(address _treasury) external;
	function setPerformanceFee(uint256 _performanceFee) external;
	function setRewardPerBlock(uint256 _rewardPerBlock) external;

	// emitted events
	event ChangeTreasury(address _oldTreasury, address _newTreasury);
	event ChangePerformanceFee(uint256 _oldPerformanceFee, uint256 _newPerformanceFee);
	event ChangeRewardPerBlock(uint256 _oldRewardPerBlock, uint256 _newRewardPerBlock);
}
