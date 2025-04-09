// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Clones } from "@openzeppelin/contracts/proxy/Clones.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Holding } from "../../src/Holding.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";
import { SimpleContract } from "../utils/mocks/SimpleContract.sol";

contract HoldingTest is BasicContractsFixture {
    using Math for uint256;

    event EmergencyInvokerSet(address indexed oldInvoker, address indexed newInvoker);

    Holding holdingImplementation;
    Holding holdingClone;

    address[] internal allowedCallers;

    function setUp() public {
        init();

        allowedCallers = [
            manager.holdingManager(),
            manager.liquidationManager(),
            manager.swapManager(),
            address(strategyWithoutRewardsMock)
        ];

        holdingImplementation = new Holding();
        holdingClone = Holding(Clones.clone(address(holdingImplementation)));
        holdingClone.init(address(manager));
    }

    // Tests if init fails correctly when trying to initialize the implementation contract
    function test_init_when_initializingImplementation() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        holdingImplementation.init(address(1));
    }

    // Tests if init fails correctly when manager address is address(0)
    function test_init_when_invalidManager() public {
        Holding badHoldingClone = Holding(Clones.clone(address(holdingImplementation)));
        vm.expectRevert(bytes("3065"));
        badHoldingClone.init(address(0));
    }

    // Tests if init works correctly when authorized
    function test_init_when_authorized(
        address _randomManager
    ) public {
        vm.assume(_randomManager != address(0));
        Holding goodHoldingClone = Holding(Clones.clone(address(holdingImplementation)));

        goodHoldingClone.init(address(_randomManager));
        assertEq(address(goodHoldingClone.manager()), _randomManager, "Manager set incorrect after init");
    }

    // Tests if approve fails correctly when unauthorized
    function test_approve_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holdingClone.approve(address(usdc), to, type(uint256).max);

        assertEq(usdc.allowance(address(holdingClone), to), 0, "Holding wrongfully approved when unauthorized caller");
    }

    // Tests if approve works correctly when authorized
    function test_approve_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(caller, caller);
        holdingClone.approve(address(usdc), _to, _amount);

        assertEq(usdc.allowance(address(holdingClone), _to), _amount, "Holding did not approve when authorized");
    }

    // Tests if genericCall fails correctly when unauthorized
    function test_genericCall_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holdingClone.genericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256("approve(address,uint256)")), to, type(uint256).max)
        );

        assertEq(usdc.allowance(address(holdingClone), to), 0, "Generic call succeeded when unauthorized caller");
    }

    // Tests if genericCall works correctly when authorized
    function test_genericCall_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(caller, caller);
        holdingClone.genericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256(("approve(address,uint256)"))), _to, _amount)
        );

        assertEq(usdc.allowance(address(holdingClone), _to), _amount, "Generic call failed when authorized");
    }

    // Tests if transfer fails correctly when unauthorized
    function test_transfer_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        address to = address(uint160(uint256(keccak256("random to"))));

        deal(address(usdc), address(holdingClone), type(uint256).max);

        vm.prank(_caller);
        vm.expectRevert(bytes("1000"));
        holdingClone.transfer(address(usdc), to, type(uint256).max);

        assertEq(usdc.balanceOf(to), 0, "Transferred when unauthorized caller");
    }

    // Tests if transfer works correctly when authorized
    function test_transfer_when_authorized(uint256 _callerId, address _to, uint256 _amount) public {
        vm.assume(_to != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        vm.assume(_to != address(holdingClone));

        uint256 toBalanceBefore = usdc.balanceOf(_to);

        deal(address(usdc), address(holdingClone), type(uint256).max);

        vm.prank(caller, caller);
        holdingClone.transfer(address(usdc), _to, _amount);

        assertEq(usdc.balanceOf(_to), toBalanceBefore + _amount, "Didn't transfer when authorized");
    }

    // Tests if set emergency invoker works correctly when authorized
    function test_emergency_invoker_authorized(
        address _caller
    ) public {
        assumeNotOwnerNotZero(_caller);
        SimpleContract simpleContract = new SimpleContract();

        vm.prank(OWNER);
        manager.whitelistContract(address(simpleContract));

        vm.prank(_caller);
        address holding = simpleContract.shouldCreateHolding(address(holdingManager));

        Holding holdingContract = Holding(holding);
        address holdingUser = holdingManager.holdingUser(holding);

        vm.expectEmit(true, true, false, false);
        emit EmergencyInvokerSet(holdingContract.emergencyInvoker(), _caller);

        vm.startPrank(address(simpleContract), address(simpleContract));
        holdingContract.setEmergencyInvoker(_caller);
        vm.stopPrank();
    }

    // Tests if set emergency invoker works correctly when unauthorized
    function test_emergency_invoker_unauthorized(address _caller, address _not_auth_caller) public {
        assumeNotOwnerNotZero(_caller);
        SimpleContract simpleContract = new SimpleContract();

        vm.prank(OWNER);
        manager.whitelistContract(address(simpleContract));

        vm.prank(_caller);
        address holding = simpleContract.shouldCreateHolding(address(holdingManager));

        Holding holdingContract = Holding(holding);
        address holdingUser = holdingManager.holdingUser(holding);

        vm.startPrank(_not_auth_caller, _not_auth_caller);
        vm.expectRevert(bytes("1000"));
        holdingContract.setEmergencyInvoker(_not_auth_caller);
        vm.stopPrank();
    }

    // Tests emergency generic call works correctly when authorized
    function test_emergency_generic_call_authorized(
        address _caller
    ) public {
        assumeNotOwnerNotZero(_caller);
        SimpleContract simpleContract = new SimpleContract();

        vm.startPrank(OWNER);
        manager.whitelistContract(address(simpleContract));
        manager.updateInvoker(_caller, true);
        vm.stopPrank();

        vm.prank(_caller);
        address holding = simpleContract.shouldCreateHolding(address(holdingManager));

        Holding holdingContract = Holding(holding);

        vm.prank(address(simpleContract), address(simpleContract));
        holdingContract.setEmergencyInvoker(_caller);

        vm.prank(_caller, _caller);
        holdingContract.emergencyGenericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256(("approve(address,uint256)"))), _caller, 10_000)
        );
    }

    // Tests emergency generic call works correctly when unauthorized
    function test_emergency_generic_call_unauthorized(
        address _caller
    ) public {
        assumeNotOwnerNotZero(_caller);
        SimpleContract simpleContract = new SimpleContract();

        vm.startPrank(OWNER);
        manager.whitelistContract(address(simpleContract));
        vm.stopPrank();

        vm.prank(_caller);
        address holding = simpleContract.shouldCreateHolding(address(holdingManager));

        Holding holdingContract = Holding(holding);

        vm.startPrank(_caller, _caller);
        vm.expectRevert(bytes("1000"));
        holdingContract.emergencyGenericCall(
            address(usdc), abi.encodeWithSelector(bytes4(keccak256(("approve(address,uint256)"))), _caller, 10_000)
        );
        vm.stopPrank();
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
