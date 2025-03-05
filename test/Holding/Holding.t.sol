// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Holding } from "../../src/Holding.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";
import { SimpleContract } from "../utils/mocks/SimpleContract.sol";

contract HoldingTest is BasicContractsFixture {
    using Math for uint256;

    address[] internal allowedCallers;

    function setUp() public {
        init();

        allowedCallers = [
            manager.strategyManager(),
            manager.holdingManager(),
            manager.liquidationManager(),
            manager.swapManager(),
            address(strategyWithoutRewardsMock)
        ];
    }

    // Tests if init fails correctly when already initialized
    function test_init_when_alreadyInitialized() public {
        Holding holding = new Holding();
        holding.init(address(1));
        vm.expectRevert(bytes("3072"));
        holding.init(address(1));
    }

    // Tests if init fails correctly when managerContainer address is address(0)
    function test_init_when_invalidManagerContainer() public {
        Holding holding = new Holding();
        vm.expectRevert(bytes("3065"));
        holding.init(address(0));
    }

    // Tests if init works correctly when authorized
    function test_init_when_authorized(
        address _randomContainer
    ) public {
        vm.assume(_randomContainer != address(0));
        Holding holding = new Holding();
        holding.init(address(_randomContainer));
        assertEq(address(holding.managerContainer()), _randomContainer, "Manager Container set incorrect after init");
    }

    // Tests if approve fails correctly when unauthorized
    function test_approve_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));
        Holding holding = createHolding();

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holding.approve(address(usdc), to, type(uint256).max);

        assertEq(usdc.allowance(address(holding), to), 0, "Holding wrongfully approved when unauthorized caller");
    }

    // Tests if approve works correctly when authorized
    function test_approve_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        Holding holding = createHolding();

        vm.prank(caller, caller);
        holding.approve(address(usdc), _to, _amount);

        assertEq(usdc.allowance(address(holding), _to), _amount, "Holding did not approve when authorized");
    }

    // Tests if genericCall fails correctly when unauthorized
    function test_genericCall_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));
        Holding holding = createHolding();

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holding.genericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")), to, type(uint256).max)
        );

        assertEq(usdc.allowance(address(holding), to), 0, "Generic call succeeded when unauthorized caller");
    }

    // Tests if genericCall works correctly when authorized
    function test_genericCall_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        Holding holding = createHolding();

        vm.prank(caller, caller);
        holding.genericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256(("approve(address,uint256)"))), _to, _amount)
        );

        assertEq(usdc.allowance(address(holding), _to), _amount, "Generic call failed when authorized");
    }

    // Tests if transfer fails correctly when unauthorized
    function test_transfer_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));
        Holding holding = createHolding();

        deal(address(usdc), address(holding), type(uint256).max);

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holding.transfer(address(usdc), to, type(uint256).max);

        assertEq(usdc.balanceOf(to), 0, "Transferred when unauthorized caller");
    }

    // Tests if transfer works correctly when authorized
    function test_transfer_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        Holding holding = createHolding();
        vm.assume(_to != address(holding));

        uint256 toBalanceBefore = usdc.balanceOf(_to);

        deal(address(usdc), address(holding), type(uint256).max);

        vm.prank(caller, caller);
        holding.transfer(address(usdc), _to, _amount);

        assertEq(usdc.balanceOf(_to), toBalanceBefore + _amount, "Didn't transfer when authorized");
    }

    // Utility functions

    function createHolding() internal returns (Holding holding) {
        holding = new Holding();
        holding.init(address(managerContainer));
    }

    // Modifiers

    modifier onlyNotAllowed(
        address _caller
    ) {
        vm.assume(_caller != address(0));
        for (uint256 i = 0; i < allowedCallers.length; i++) {
            vm.assume(_caller != allowedCallers[i]);
        }

        _;
    }
}
