// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.6.0;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { Transfers } from "./modules/Transfers.sol";

contract Airdrop is Ownable
{
	struct ListInfo {
		address token;
		string description;
		uint256 totalAmount;
		uint256 pendingAmount;
		uint256 cursor;
	}

	struct PaymentInfo {
		address receiver;
		uint256 amount;
	}

	ListInfo[] public listInfo;
	mapping (uint256 => PaymentInfo[]) public paymentsInfo;

	function listCount() external view returns (uint256 _count)
	{
		return listInfo.length;
	}

	function createList(address _token, string memory _description) external onlyOwner
	{
		listInfo.push(ListInfo({ token: _token, description: _description, totalAmount: 0, pendingAmount: 0, cursor: 0 }));
	}

	function registerPayments(uint256 _listId, address[] memory _receivers, uint256 _amount) external onlyOwner
	{
		require(_listId < listInfo.length, "invalid list id");
		uint256 _count = _receivers.length;
		require(_count > 0, "empty set");
		require(_amount > 0, "zero amount");
		uint256 _batchAmount = _amount * _count;
		require(_batchAmount / _amount == _count, "amount overflow");
		ListInfo storage _list = listInfo[_listId];
		PaymentInfo[] storage _payments = paymentsInfo[_listId];
		require(_list.totalAmount <= uint256(-1) - _batchAmount, "excess amount");
		_list.totalAmount += _batchAmount;
		_list.pendingAmount += _batchAmount;
		for (uint256 _i = 0; _i < _count; _i++) {
			address _receiver = _receivers[_i];
			_payments.push(PaymentInfo({ receiver: _receiver, amount: _amount }));
		}
	}

	function registerPayments(uint256 _listId, address[] memory _receivers, uint256[] memory _amounts) external onlyOwner
	{
		require(_listId < listInfo.length, "invalid list id");
		uint256 _count = _receivers.length;
		require(_count > 0, "empty set");
		require(_amounts.length == _count, "length mismatch");
		ListInfo storage _list = listInfo[_listId];
		PaymentInfo[] storage _payments = paymentsInfo[_listId];
		for (uint256 _i = 0; _i < _count; _i++) {
			address _receiver = _receivers[_i];
			uint256 _amount = _amounts[_i];
			require(_amount > 0, "zero amount");
			require(_list.totalAmount <= uint256(-1) - _amount, "excess amount");
			_list.totalAmount += _amount;
			_list.pendingAmount += _amount;
			_payments.push(PaymentInfo({ receiver: _receiver, amount: _amount }));
		}
	}

	function cancelPayment(uint256 _listId, uint256 _index) external onlyOwner
	{
		require(_listId < listInfo.length, "invalid list id");
		ListInfo storage _list = listInfo[_listId];
		PaymentInfo[] storage _payments = paymentsInfo[_listId];
		uint256 _length = _payments.length;
		require(_list.cursor <= _index && _index < _length, "invalid index");
		if (_index < _length - 1) {
			_payments[_index] = _payments[_length - 1];
		}
		_payments.pop();
	}

	function airdrop(uint256 _listId, uint256 _limit) external onlyOwner
	{
		address _from = msg.sender;
		require(_listId < listInfo.length, "invalid list id");
		ListInfo storage _list = listInfo[_listId];
		PaymentInfo[] storage _payments = paymentsInfo[_listId];
		uint256 _offset = _list.cursor;
		uint256 _maxLimit = _payments.length - _offset;
		if (_limit == 0 || _limit > _maxLimit) {
			_limit = _maxLimit;
		}
		require(_limit > 0, "empty set");
		Transfers._pullFunds(_list.token, _from, _list.pendingAmount);
		uint256 _cursor = _offset + _limit;
		for (uint256 _i = _offset; _i < _cursor; _i++) {
			PaymentInfo storage _payment = _payments[_i];
			Transfers._pushFunds(_list.token, _payment.receiver, _payment.amount);
			_list.pendingAmount -= _payment.amount;
		}
		_list.cursor = _cursor;
		if (_list.pendingAmount > 0) {
			Transfers._pushFunds(_list.token, _from, _list.pendingAmount);
		}
		emit AirdropPerformed(_listId, _offset, _limit);
	}

	event AirdropPerformed(uint256 indexed _listId, uint256 _offset, uint256 _limit);
}
