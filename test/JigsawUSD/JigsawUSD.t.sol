// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";

import { JigsawUSD } from "../../src/JigsawUSD.sol";

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
}
