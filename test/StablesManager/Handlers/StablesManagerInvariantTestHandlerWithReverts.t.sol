pragma solidity ^0.8.20;

import "forge-std/console.sol";

import { CommonBase } from "forge-std/Base.sol";
import { StdCheats } from "forge-std/StdCheats.sol";
import { StdUtils } from "forge-std/StdUtils.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import { HoldingManager } from "../../../src/HoldingManager.sol";

import { SharesRegistry } from "../../../src/SharesRegistry.sol";
import { StablesManager } from "../../../src/StablesManager.sol";
import { IHandler } from "./IHandler.sol";

contract StablesManagerInvariantTestHandlerWithReverts is CommonBase, StdCheats, StdUtils, IHandler {
    using EnumerableSet for EnumerableSet.AddressSet;

    address internal collateral;
    HoldingManager internal holdingManager;
    StablesManager internal stablesManager;
    SharesRegistry internal sharesRegistry;

    EnumerableSet.AddressSet internal borrowersSet;

    address[] public USER_ADDRESSES = [
        address(uint160(uint256(keccak256("user1")))),
        address(uint160(uint256(keccak256("user2")))),
        address(uint160(uint256(keccak256("user3")))),
        address(uint160(uint256(keccak256("user4")))),
        address(uint160(uint256(keccak256("user5"))))
    ];

    mapping(address => address) internal userHolding;
    mapping(address => uint256) internal borrowed;
    mapping(address => uint256) internal collateralDeposited;

    constructor(
        StablesManager _stablesManager,
        HoldingManager _holdingManager,
        address _sharesRegistry,
        address _collateral
    ) {
        stablesManager = _stablesManager;
        holdingManager = _holdingManager;
        sharesRegistry = SharesRegistry(_sharesRegistry);
        collateral = _collateral;
    }

    // Calls that should not revert to cover happy paths

    function borrow_always(uint256 _amount, uint256 user_idx) public {
        _borrow(pickUpUser(user_idx), _amount);
    }

    function repay_always(uint256 _amount, uint256 user_idx) external {
        address user = pickUpUserFromBorrowers(user_idx);

        if (user == address(0)) return;
        if (borrowed[user] == 0) _borrow(user, _amount);

        _amount = bound(_amount, 1, borrowed[user]);

        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.repay(userHolding[user], collateral, _amount, user);

        borrowed[user] -= _amount;

        if (borrowed[user] == 0) borrowersSet.remove(user);
    }

    function withdraw_always(uint256 _amount, uint256 user_idx) external {
        address user = pickUpUserFromBorrowers(user_idx);

        if (user == address(0)) return;
        if (collateralDeposited[user] == 0) return;
        _amount = bound(_amount, 1, collateralDeposited[user]);

        if ((collateralDeposited[user] - _amount) / 2 < borrowed[user]) return;

        vm.prank(user, user);
        holdingManager.withdraw(collateral, _amount);

        collateralDeposited[user] -= _amount;
    }

    // Calls that should sometimes revert to ensure that state variables are always correct

    function borrow_withReverts(uint256 _amount, uint256 user_idx) public {
        address user = pickUpUser(user_idx);

        _deposit(user, _amount);

        vm.startPrank(address(holdingManager), address(holdingManager));
        stablesManager.borrow(userHolding[user], collateral, _amount, 0, true);
        vm.stopPrank();

        borrowed[user] += _amount;
        borrowersSet.add(user);
    }

    function repay_withReverts(uint256 _amount, uint256 user_idx) external {
        address user = pickUpUserFromBorrowers(user_idx);

        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.repay(userHolding[user], collateral, _amount, user);

        borrowed[user] -= _amount;

        if (borrowed[user] == 0) borrowersSet.remove(user);
    }

    function withdraw_withReverts(uint256 _amount, uint256 user_idx) external {
        address user = pickUpUserFromBorrowers(user_idx);

        vm.prank(user, user);
        holdingManager.withdraw(collateral, _amount);

        collateralDeposited[user] -= _amount;
    }

    // Utility functions

    function getTotalBorrowed() external view returns (uint256 totalBorrowed) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalBorrowed += borrowed[USER_ADDRESSES[i]];
        }
    }

    function getTotalBorrowedFromRegistry() external view returns (uint256 totalBorrowed) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalBorrowed += sharesRegistry.borrowed(userHolding[USER_ADDRESSES[i]]);
        }
    }

    function getTotalCollateral() external view returns (uint256 totalCollateral) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalCollateral += collateralDeposited[USER_ADDRESSES[i]];
        }
    }

    function getTotalCollateralFromRegistry() external view returns (uint256 totalCollateral) {
        for (uint256 i = 0; i < USER_ADDRESSES.length; i++) {
            totalCollateral += sharesRegistry.collateral(userHolding[USER_ADDRESSES[i]]);
        }
    }

    function _borrow(address _user, uint256 _amount) private {
        if (userHolding[_user] == address(0)) initializeUser(_user);

        _amount = bound(_amount, 1, 100_000e18);

        _deposit(_user, _amount);

        vm.prank(address(holdingManager), address(holdingManager));
        stablesManager.borrow(userHolding[_user], collateral, _amount, 0, true);

        borrowed[_user] += _amount;
        borrowersSet.add(_user);
    }

    function _deposit(address _user, uint256 _mintAmount) private {
        uint256 collateralAmount = _mintAmount * 2;
        deal(collateral, _user, collateralAmount);

        vm.prank(_user, _user);
        IERC20(collateral).approve(address(holdingManager), collateralAmount);
        vm.prank(_user, _user);
        holdingManager.deposit(collateral, collateralAmount);

        collateralDeposited[_user] += collateralAmount;
    }

    function initializeUser(
        address _user
    ) private {
        vm.prank(_user, _user);
        userHolding[_user] = holdingManager.createHolding();
    }

    function pickUpUser(
        uint256 _user_idx
    ) public view returns (address) {
        _user_idx = _user_idx % USER_ADDRESSES.length;
        return USER_ADDRESSES[_user_idx];
    }

    function pickUpUserFromBorrowers(
        uint256 _user_idx
    ) public view returns (address) {
        uint256 BorrowersNumber = borrowersSet.length();
        if (BorrowersNumber == 0) return address(0);

        _user_idx = bound(_user_idx, 0, BorrowersNumber - 1);

        return borrowersSet.at(_user_idx);
    }
}
