// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BasicContractsFixture, Manager } from "../fixtures/BasicContractsFixture.t.sol";

import { IJigsawUSD, JigsawUSD } from "../../src/JigsawUSD.sol";

contract JigsawUsdTest is BasicContractsFixture {
    using Math for uint256;

    function setUp() public {
        init();
    }

    function test_should_wrong_initialization_values() public {
        vm.expectRevert(bytes("3065"));
        new JigsawUSD(address(this), address(0));
    }

    function test_should_exceed_mint_limit_values(
        address user
    ) public {
        vm.prank(OWNER);
        jUsd.updateMintLimit(10);

        address stablesManagerAddress = address(stablesManager);
        vm.prank(stablesManagerAddress, stablesManagerAddress);
        vm.expectRevert(bytes("2007"));
        jUsd.mint(user, 100);
    }

    function test_should_mint_and_burn(
        address user
    ) public {
        vm.assume(user != address(0));

        address stablesManagerAddress = address(stablesManager);
        vm.prank(stablesManagerAddress, stablesManagerAddress);
        jUsd.mint(user, 100);

        vm.prank(user, user);
        jUsd.burn(100);
    }

    function test_should_update_the_mint_limit(
        address user
    ) public {
        vm.assume(user != OWNER);

        vm.expectRevert();
        vm.prank(user);
        jUsd.updateMintLimit(100);

        vm.startPrank(OWNER);
        vm.expectRevert(bytes("2001"));
        jUsd.updateMintLimit(0);

        jUsd.updateMintLimit(100);
    }

    function test_should_not_mint(
        address user
    ) public {
        vm.assume(user != address(0));

        vm.expectRevert(bytes("1000"));
        jUsd.mint(user, 100);

        vm.expectRevert(bytes("1000"));
        jUsd.burnFrom(user, 100);
    }

    function test_updateManager() public {
        address newManager = address(new Manager(OWNER, address(weth), address(jUsdOracle), bytes("")));

        uint256 updateTimestamp = block.timestamp;
        vm.expectEmit();
        emit IJigsawUSD.NewManagerRequested(newManager);
        vm.prank(OWNER);
        jUsd.requestNewManager(newManager);

        vm.assertEq(address(jUsd.manager()), address(manager), "Old manager changed wrongfully");
        vm.assertEq(jUsd.newManager(), newManager, "New manager wasn't saved");
        vm.assertEq(jUsd.newManagerTimestamp(), updateTimestamp, "newManagerTimestamp wrong");

        vm.expectRevert(bytes("3066"));
        vm.prank(OWNER);
        jUsd.acceptManager();

        skip(2 hours);
        vm.expectEmit();
        emit IJigsawUSD.ManagerUpdated(address(manager), newManager);
        vm.prank(OWNER);
        jUsd.acceptManager();

        vm.assertEq(address(jUsd.manager()), newManager, "Updated manager is wrong");
        vm.assertEq(address(jUsd.newManager()), address(0), "New manager is not reset to address(0)");
        vm.assertEq(jUsd.newManagerTimestamp(), 0, "newManagerTimestamp is not reset to 0");

        address newStablesManager = vm.randomAddress();
        uint256 testMintAmt = 420;

        vm.prank(OWNER);
        Manager(newManager).setStablecoinManager(newStablesManager);

        vm.prank(newStablesManager);
        jUsd.mint(address(this), testMintAmt);

        vm.assertEq(jUsd.balanceOf(address(this)), testMintAmt, "Tokens not minted");
    }
}
