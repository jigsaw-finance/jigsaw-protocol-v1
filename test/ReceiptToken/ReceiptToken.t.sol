// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { ReceiptToken } from "../../src/ReceiptToken.sol";
import { ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";

contract ReceiptTokenTest is Test {
    event MinterUpdated(address oldMinter, address newMinter);

    ReceiptToken internal receiptToken;
    ReceiptTokenFactory internal receiptTokenFactory;

    address internal OWNER = vm.addr(uint256(keccak256(bytes("OWNER"))));

    function setUp() public {
        receiptToken = new ReceiptToken();
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(receiptToken));
    }

    // Test if initialize function reverts correctly when __minter is set to address(0)
    function test_initialize_RT_when_address0() public {
        vm.expectRevert(bytes("3000"));
        receiptTokenFactory.createReceiptToken({ _name: "", _symbol: "", _minter: address(0), _owner: address(0) });
    }

    // Test if setMinter function reverts correctly when _minter is the same address
    function test_setMinter_when_sameAddress() public {
        address oldMinter = receiptToken.minter();

        vm.expectRevert(bytes("3062"));
        vm.prank(oldMinter);
        receiptToken.setMinter(oldMinter);
    }

    // Test if setMinter function works correctly when authorized
    function test_setMinter_when_authorized(
        address _minter
    ) public {
        vm.assume(_minter != address(0));
        address oldMinter = receiptToken.minter();
        vm.assume(_minter != oldMinter);

        vm.expectEmit();
        emit MinterUpdated(oldMinter, _minter);

        vm.prank(oldMinter);
        receiptToken.setMinter(_minter);

        assertEq(_minter, receiptToken.minter());
    }

    // Test if renounceOwnership function reverts correctly
    function test_renounceOwnership_RT() public {
        vm.expectRevert(bytes("1000"));
        receiptToken.renounceOwnership();
    }

    function test_only_minter_or_owner(address _user) public {
        vm.expectRevert(bytes("1000"));
        receiptToken.mint(_user, 0);

        vm.expectRevert(bytes("1000"));
        receiptToken.setMinter(_user);

        vm.expectRevert(bytes("1000"));
        receiptToken.burnFrom(_user, 100);
    }
}
