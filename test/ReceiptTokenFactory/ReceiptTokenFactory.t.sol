// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IReceiptTokenFactory, ReceiptTokenFactory } from "../../src/ReceiptTokenFactory.sol";

contract ReceiptTokenFactoryTest is Test {
    ReceiptTokenFactory internal receiptTokenFactory;

    address internal OWNER = vm.addr(uint256(keccak256(bytes("OWNER"))));

    function test_initialization_when_referenceImplementationHasNoCode() public {
        vm.expectRevert(bytes("3096"));
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(0));
    }

    function test_initialization_when_validReferenceImplementation() public {
        vm.expectEmit();
        emit IReceiptTokenFactory.ReceiptTokenImplementationUpdated(address(this));

        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(this));
        vm.assertEq(
            address(receiptTokenFactory.referenceImplementation()),
            address(this),
            "ReferenceImplementation is set wrong"
        );
    }

    // Test if setReceiptTokenReferenceImplementation reverts correctly when receipt token implementation has no code
    function test_setReceiptTokenReferenceImplementation_when_referenceImplementationHasNoCode() public {
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(this));

        vm.prank(OWNER);
        vm.expectRevert(bytes("3096"));
        receiptTokenFactory.setReceiptTokenReferenceImplementation(address(0));
    }

    // Test if setReceiptTokenReferenceImplementation reverts correctly when receipt token implementation is the same
    function test_setReceiptTokenReferenceImplementation_when_newAddressIsTheSame() public {
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(this));

        vm.prank(OWNER);
        vm.expectRevert(bytes("3062"));
        receiptTokenFactory.setReceiptTokenReferenceImplementation(address(this));
    }

    // Test if setReceiptTokenReferenceImplementation works correctly when receipt token implementation is valid
    function test_setReceiptTokenReferenceImplementation_when_validReferenceImplementation() public {
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(new ReceiptTokenFactory(OWNER, address(this))));

        vm.expectEmit();
        emit IReceiptTokenFactory.ReceiptTokenImplementationUpdated(address(this));

        vm.prank(OWNER);
        receiptTokenFactory.setReceiptTokenReferenceImplementation(address(this));

        vm.assertEq(
            address(receiptTokenFactory.referenceImplementation()),
            address(this),
            "ReferenceImplementation is set wrong"
        );
    }

    // Test if renounce ownership overridden, to avoid losing contract's ownership.
    function test_renounceOwnershipImplementation() public {
        receiptTokenFactory = new ReceiptTokenFactory(OWNER, address(this));

        vm.prank(OWNER);
        vm.expectRevert(bytes("1000"));
        receiptTokenFactory.renounceOwnership();
    }
}
