// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20, IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { Holding } from "../../src/Holding.sol";

import { IHoldingManager } from "../../src/interfaces/core/IHoldingManager.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { OperationsLib } from "../../src/libraries/OperationsLib.sol";

import { SampleTokenERC20 } from "../utils/mocks/SampleTokenERC20.sol";

import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";
import { SimpleContract } from "../utils/mocks/SimpleContract.sol";

contract HoldingManagerTest is BasicContractsFixture {
    using Math for uint256;

    event ContractWhitelisted(address indexed contractAddress);
    event HoldingCreated(address indexed user, address indexed holdingAddress);
    event Deposit(address indexed holding, address indexed token, uint256 amount);
    event NativeCoinWrapped(address user, uint256 amount);
    event NativeCoinUnwrapped(address user, uint256 amount);
    event Withdrawal(address indexed holding, address indexed token, uint256 totalAmount, uint256 feeAmount);
    event Borrowed(address indexed holding, address indexed token, uint256 amount, bool mintToUser);
    event BorrowedMultiple(address indexed holding, uint256 length, bool mintedToUser);
    event Repaid(address indexed holding, address indexed token, uint256 amount, bool repayFromUser);
    event RepaidMultiple(address indexed holding, uint256 length, bool repaidFromUser);

    function setUp() public {
        init();
    }

    function test_should_not_create_holding_from_not_whitelisted() public {
        vm.startPrank(OWNER);
        SimpleContract simpleContract = new SimpleContract();

        vm.expectRevert(bytes("1000"));
        simpleContract.shouldCreateHolding(address(holdingManager));
    }

    function test_should_create_holding_from_whitelisted(
        address _user
    ) public {
        assumeNotOwnerNotZero(_user);

        vm.startPrank(OWNER);
        SimpleContract simpleContract = new SimpleContract();

        // The event we expect
        vm.expectEmit(true, false, false, false);
        emit ContractWhitelisted(address(simpleContract));
        manager.whitelistContract(address(simpleContract));

        vm.startPrank(_user, _user);

        address holding = simpleContract.shouldCreateHolding(address(holdingManager));

        assertEq(holdingManager.userHolding(address(simpleContract)), holding);
        assertTrue(holdingManager.isHolding(holding));
    }

    function test_should_not_be_able_to_init_an_already_initialized_holding(
        address _user
    ) public {
        assumeNotOwnerNotZero(_user);

        vm.prank(OWNER);
        manager.whitelistContract(_user);

        vm.startPrank(_user, _user);
        vm.expectEmit(true, false, false, false);
        emit HoldingCreated(_user, address(0));
        address holdingContractAddress = holdingManager.createHolding();

        Holding holdingContract = Holding(holdingContractAddress);
        vm.expectRevert(bytes("3072"));
        holdingContract.init(address(0));
    }

    function test_should_not_be_able_to_create_multiple_holding_for_myself(
        address _user
    ) public {
        assumeNotOwnerNotZero(_user);

        vm.prank(OWNER);
        manager.whitelistContract(_user);

        vm.startPrank(_user, _user);
        holdingManager.createHolding();

        vm.expectRevert(bytes("1101"));
        holdingManager.createHolding();
    }

    function test_should_not_let_owner_renounce_ownership() public {
        vm.prank(OWNER);
        vm.expectRevert(bytes("1000"));
        holdingManager.renounceOwnership();
    }

    function test_should_test_pause(
        address _user
    ) public {
        assumeNotOwnerNotZero(_user);

        vm.prank(OWNER);
        manager.whitelistContract(_user);

        vm.prank(_user);
        vm.expectRevert();
        holdingManager.pause();

        vm.prank(OWNER);
        holdingManager.pause();

        vm.prank(_user);
        vm.expectRevert();
        holdingManager.createHolding();

        vm.prank(OWNER);
        holdingManager.unpause();

        vm.prank(_user);
        holdingManager.createHolding();
    }

    // Tests if wrapAndDeposit reverts correctly when wETH is not whitelisted in Manager contract
    function test_wrapAndDeposit_when_wEthNotWhitelisted(
        uint256 _amount
    ) public {
        vm.prank(manager.owner(), manager.owner());
        manager.removeToken(address(weth));

        address user = address(uint160(uint256(keccak256(bytes("user")))));
        deal(user, _amount);

        vm.prank(user, user);
        vm.expectRevert(bytes("3001"));
        holdingManager.wrapAndDeposit{ value: _amount }();
    }

    // Tests if wrapAndDeposit reverts correctly when caller doesn't have holding in the system
    function test_wrapAndDeposit_when_invalidHolding(address _user, uint256 _amount) public {
        vm.assume(_user != address(0));
        deal(_user, _amount);

        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.wrapAndDeposit{ value: _amount }();
    }

    // Tests if wrapAndDeposit reverts correctly when the contract is paused
    function test_wrapAndDeposit_when_paused(
        uint256 _amount
    ) public {
        vm.assume(_amount != 0);
        address user = address(uint160(uint256(keccak256(bytes("user")))));
        deal(user, _amount);

        vm.prank(user, user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(user, user);
        vm.expectRevert();
        holdingManager.wrapAndDeposit{ value: _amount }();
    }

    // Tests if wrapAndDeposit reverts correctly when msg.value = 0
    function test_wrapAndDeposit_when_0value() public {
        address user = address(uint160(uint256(keccak256(bytes("user")))));

        vm.prank(user, user);
        holdingManager.createHolding();

        vm.prank(user, user);
        vm.expectRevert(bytes("2001"));
        holdingManager.wrapAndDeposit{ value: 0 }();
    }

    // Tests if wrapAndDeposit works correctly when authorized
    function test_wrapAndDeposit_when_authorized(uint256 _amount, address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != address(weth));
        vm.assume(_amount != 0 && _amount < 1e75);
        deal(_user, _amount);
        uint256 userEthBalanceBefore = _user.balance;

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();
        vm.expectEmit();
        emit NativeCoinWrapped(_user, _amount);
        emit Deposit(holding, address(weth), _amount);
        holdingManager.wrapAndDeposit{ value: _amount }();
        vm.stopPrank();

        assertEq(_user.balance, userEthBalanceBefore - _amount, "ETH wasn't taken from user after wrapAndDeposit");
        assertEq(weth.balanceOf(holding), _amount, "Holding hasn't received wETH after wrapAndDeposit");
        assertEq(
            ISharesRegistry(registries[address(weth)]).collateral(holding),
            _amount,
            "Registry didn't track user's deposit"
        );
    }

    // Tests if withdraw reverts correctly when user wants to withdraw invalid token
    function test_withdraw_when_invalidToken() public {
        address user = address(uint160(uint256(keccak256(bytes("user")))));

        vm.prank(user, user);
        vm.expectRevert(bytes("3000"));
        holdingManager.withdraw(address(0), 0);
    }

    // Tests if withdraw reverts correctly when user wants to withdraw invalid amount
    function test_withdraw_when_invalidAmount() public {
        address user = address(uint160(uint256(keccak256(bytes("user")))));

        vm.prank(user, user);
        vm.expectRevert(bytes("2001"));
        holdingManager.withdraw(address(1), 0);
    }

    // Tests if withdraw reverts correctly when caller doesn't have holding in the system
    function test_withdraw_when_invalidHolding(
        address _user
    ) public {
        vm.assume(_user != address(0));
        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.withdraw(address(1), 1);
    }

    // Tests if withdraw reverts correctly when the contract is paused
    function test_withdraw_when_paused(
        address _user
    ) public {
        vm.assume(_user != address(0));

        vm.prank(_user, _user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(_user, _user);
        vm.expectRevert();
        holdingManager.withdraw(address(usdc), 1);
    }

    // Tests if withdraw reverts correctly when token is not withdrawable
    function test_withdraw_when_tokenNotWithdrawable(
        uint256 _depositAmount,
        uint256 _withdrawAmount,
        address _user
    ) public {
        vm.assume(_user != address(0));
        vm.assume(_depositAmount != 0 && _depositAmount < 1e75);
        uint256 withdrawAmount = bound(_withdrawAmount, 1, _depositAmount);

        deal(address(usdc), _user, _depositAmount);

        vm.startPrank(_user, _user);
        holdingManager.createHolding();
        usdc.approve(address(holdingManager), _depositAmount);
        holdingManager.deposit(address(usdc), _depositAmount);
        vm.stopPrank();

        vm.prank(manager.owner(), manager.owner());
        manager.addNonWithdrawableToken(address(usdc));

        vm.prank(_user, _user);
        vm.expectRevert(bytes("3071"));
        holdingManager.withdraw(address(usdc), withdrawAmount);
    }

    // Tests if withdraw works when withdrawable token has no registry in the system
    function test_withdraw_when_noRegistryForToken(
        address _user
    ) public {
        vm.assume(_user != address(0));

        SampleTokenERC20 randomToken = new SampleTokenERC20("RT", "RT", 0);

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();
        deal(address(randomToken), holding, 10);

        holdingManager.withdraw(address(randomToken), 10);
        vm.stopPrank();
    }

    // Tests if withdraw reverts correctly when user will become insolvent after withdraw
    function test_withdraw_when_insolvent(uint256 _depositAmount, address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_depositAmount > 200 && _depositAmount < 100_000e6);

        deal(address(usdc), _user, _depositAmount);

        vm.startPrank(_user, _user);
        holdingManager.createHolding();
        usdc.approve(address(holdingManager), _depositAmount);
        holdingManager.deposit(address(usdc), _depositAmount);
        holdingManager.borrow(address(usdc), _depositAmount / 2, true);

        vm.expectRevert(bytes("3009"));
        holdingManager.withdraw(address(usdc), _depositAmount);
        vm.stopPrank();
    }

    // Tests if withdraw works correctly when authorized
    function test_withdraw_HM_when_authorized(uint256 _depositAmount, uint256 _withdrawAmount, address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_depositAmount > 2 && _depositAmount < 100_000e6);
        vm.assume(_user != manager.feeAddress());
        uint256 withdrawAmount = bound(_withdrawAmount, 2, _depositAmount);

        deal(address(usdc), _user, _depositAmount);

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();

        vm.assume(holding != _user);

        usdc.approve(address(holdingManager), _depositAmount);
        holdingManager.deposit(address(usdc), _depositAmount);

        uint256 userBalanceBeforeWithdraw = usdc.balanceOf(_user);
        uint256 holdingBalanceBeforeWithdraw = usdc.balanceOf(holding);
        uint256 withdrawalFeeAmount = OperationsLib.getFeeAbsolute(withdrawAmount, manager.withdrawalFee());

        vm.expectEmit();
        emit Withdrawal(holding, address(usdc), withdrawAmount, withdrawalFeeAmount);
        holdingManager.withdraw(address(usdc), withdrawAmount);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(_user),
            userBalanceBeforeWithdraw + withdrawAmount - withdrawalFeeAmount,
            "User balance incorrect after withdraw"
        );
        assertEq(
            usdc.balanceOf(holding),
            holdingBalanceBeforeWithdraw - withdrawAmount,
            "Holding balance incorrect after withdraw"
        );
        assertEq(
            usdc.balanceOf(manager.feeAddress()), withdrawalFeeAmount, "Fee address balance incorrect after withdraw"
        );
        assertEq(
            ISharesRegistry(registries[address(usdc)]).collateral(holding),
            holdingBalanceBeforeWithdraw - withdrawAmount,
            "Registry didn't track user's withdraw"
        );
    }

    //fee addr  0x758bc02523B26ab4dDcc485f982560Ba8a42A7db
    //user      0x10BA9FeBB9e3F638D00e0DA7172874cDd5407FD7
    //holding   0x10BA9FeBB9e3F638D00e0DA7172874cDd5407FD7

    // Tests if withdraw works correctly when authorized and withdrawal fee is not zero
    function test_withdraw_HM_when_fees(uint256 _depositAmount, uint256 _withdrawAmount, address _user) public {
        vm.assume(_user != address(0));
        vm.assume(_user != manager.feeAddress());
        vm.assume(_depositAmount > 2 && _depositAmount < 100_000e6);
        uint256 withdrawAmount = bound(_withdrawAmount, 2, _depositAmount);

        deal(address(usdc), _user, _depositAmount);

        vm.startPrank(manager.owner(), manager.owner());
        manager.setWithdrawalFee(500);
        vm.stopPrank();

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();

        vm.assume(holding != _user);

        usdc.approve(address(holdingManager), _depositAmount);
        holdingManager.deposit(address(usdc), _depositAmount);

        uint256 userBalanceBeforeWithdraw = usdc.balanceOf(_user);
        uint256 holdingBalanceBeforeWithdraw = usdc.balanceOf(holding);
        uint256 feeBalanceBeforeWithdraw = usdc.balanceOf(manager.feeAddress());
        uint256 withdrawalFeeAmount = OperationsLib.getFeeAbsolute(withdrawAmount, manager.withdrawalFee());

        vm.expectEmit();
        emit Withdrawal(holding, address(usdc), withdrawAmount, withdrawalFeeAmount);
        holdingManager.withdraw(address(usdc), withdrawAmount);
        vm.stopPrank();

        assertEq(
            usdc.balanceOf(_user),
            userBalanceBeforeWithdraw + withdrawAmount - withdrawalFeeAmount,
            "User balance incorrect after withdraw"
        );
        assertEq(
            usdc.balanceOf(holding),
            holdingBalanceBeforeWithdraw - withdrawAmount,
            "Holding balance incorrect after withdraw"
        );
        assertEq(
            usdc.balanceOf(manager.feeAddress()),
            feeBalanceBeforeWithdraw + withdrawalFeeAmount,
            "Fee address balance incorrect after withdraw"
        );
        assertEq(
            ISharesRegistry(registries[address(usdc)]).collateral(holding),
            holdingBalanceBeforeWithdraw - withdrawAmount,
            "Registry didn't track user's withdraw"
        );
    }

    // Tests if withdrawAndUnwrap reverts correctly when invalid amount
    function test_withdrawAndUnwrap_when_invalidAmount() public {
        address user = address(uint160(uint256(keccak256(bytes("user")))));

        vm.prank(user, user);
        vm.expectRevert(bytes("2001"));
        holdingManager.withdrawAndUnwrap(0);
    }

    // Tests if withdrawAndUnwrap reverts correctly when caller doesn't have holding in the system
    function test_withdrawAndUnwrap_when_invalidHolding(address _user, uint256 _amount) public {
        vm.assume(_amount != 0);
        vm.assume(_user != address(0));

        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.withdrawAndUnwrap(_amount);
    }

    // Tests if withdrawAndUnwrap reverts correctly when the contract is paused
    function test_withdrawAndUnwrap_when_paused(
        address _user
    ) public {
        vm.assume(_user != address(0));

        vm.prank(_user, _user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(_user, _user);
        vm.expectRevert();
        holdingManager.withdrawAndUnwrap(1);
    }

    // Tests if withdrawAndUnwrap works correctly when authorized
    function test_withdrawAndUnwrap_when_authorized(
        uint256 _depositAmount,
        uint256 _multiplier,
        uint256 _withdrawAmount
    ) public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        vm.assume(_depositAmount > 2 && _depositAmount < 1e75);
        uint256 withdrawAmount = bound(_withdrawAmount, 2, _depositAmount);

        deal(user, _depositAmount * bound(_multiplier, 1, 10));

        vm.startPrank(user, user);
        address holding = holdingManager.createHolding();
        holdingManager.wrapAndDeposit{ value: _depositAmount }();

        uint256 userEthBalanceBefore = user.balance;
        uint256 withdrawalFeeAmount = OperationsLib.getFeeAbsolute(withdrawAmount, manager.withdrawalFee());
        uint256 holdingBalanceBefore = weth.balanceOf(holding);

        vm.expectEmit();
        emit NativeCoinUnwrapped(user, withdrawAmount);
        emit Withdrawal(holding, address(weth), withdrawAmount, withdrawalFeeAmount);

        holdingManager.withdrawAndUnwrap(withdrawAmount);
        vm.stopPrank();

        assertEq(
            user.balance,
            userEthBalanceBefore + withdrawAmount - withdrawalFeeAmount,
            "User didn't receive ETH after withdrawAndUnwrap"
        );
        assertEq(
            weth.balanceOf(holding),
            holdingBalanceBefore - withdrawAmount,
            "wETH wasn't taken from holding after withdrawAndUnwrap"
        );
        assertEq(
            ISharesRegistry(registries[address(weth)]).collateral(holding),
            holdingBalanceBefore - withdrawAmount,
            "Registry didn't track user's withdrawAndUnwrap"
        );
        assertEq(
            manager.feeAddress().balance, withdrawalFeeAmount, "Fee address balance incorrect after withdrawAndUnwrap"
        );
    }

    // Tests if withdrawAndUnwrap works correctly when authorized and withdrawal fee is not zero
    function test_withdrawAndUnwrap_when_fees(
        uint256 _depositAmount,
        uint256 _multiplier,
        uint256 _withdrawAmount
    ) public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        vm.assume(_depositAmount > 2 && _depositAmount < 1e73);

        uint256 withdrawAmount = bound(_withdrawAmount, 2, _depositAmount);
        deal(user, _depositAmount * bound(_multiplier, 1, 10));

        vm.prank(manager.owner(), manager.owner());
        manager.setWithdrawalFee(500);

        vm.startPrank(user, user);
        address holding = holdingManager.createHolding();
        holdingManager.wrapAndDeposit{ value: _depositAmount }();

        uint256 userEthBalanceBefore = user.balance;
        uint256 withdrawalFeeAmount = OperationsLib.getFeeAbsolute(withdrawAmount, manager.withdrawalFee());
        uint256 holdingBalanceBefore = weth.balanceOf(holding);

        vm.expectEmit();
        emit NativeCoinUnwrapped(user, withdrawAmount);
        emit Withdrawal(holding, address(weth), withdrawAmount, withdrawalFeeAmount);
        holdingManager.withdrawAndUnwrap(withdrawAmount);
        vm.stopPrank();

        assertEq(
            user.balance,
            userEthBalanceBefore + withdrawAmount - withdrawalFeeAmount,
            "User didn't receive ETH after withdrawAndUnwrap"
        );
        assertEq(
            weth.balanceOf(holding),
            holdingBalanceBefore - withdrawAmount,
            "wETH wasn't taken from holding after withdrawAndUnwrap"
        );
        assertEq(
            ISharesRegistry(registries[address(weth)]).collateral(holding),
            holdingBalanceBefore - withdrawAmount,
            "Registry didn't track user's withdrawAndUnwrap"
        );
        assertEq(
            manager.feeAddress().balance, withdrawalFeeAmount, "Fee address balance incorrect after withdrawAndUnwrap"
        );
    }

    // Tests if withdrawAndUnwrap works correctly when authorized and transfer to fee address fails
    function test_withdrawAndUnwrap_when_feeTransferFails(
        uint256 _depositAmount,
        uint256 _multiplier,
        uint256 _withdrawAmount
    ) public {
        SimpleContract simpleContract = new SimpleContract();

        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        uint256 depositAmount = bound(_depositAmount, 1e18, 1e73);
        uint256 withdrawAmount = bound(_withdrawAmount, 1e18, depositAmount);

        deal(user, depositAmount * bound(_multiplier, 1, 10));

        vm.startPrank(manager.owner(), manager.owner());
        manager.setWithdrawalFee(500);
        manager.setFeeAddress(address(simpleContract));
        vm.stopPrank();

        vm.startPrank(user, user);
        holdingManager.createHolding();
        holdingManager.wrapAndDeposit{ value: depositAmount }();

        vm.expectRevert(bytes("3016"));
        holdingManager.withdrawAndUnwrap(withdrawAmount);
        vm.stopPrank();
    }

    // Tests if withdrawAndUnwrap works correctly when authorized and transfer to user fails
    function test_withdrawAndUnwrap_when_userTransferFails(
        uint256 _depositAmount,
        uint256 _multiplier,
        uint256 _withdrawAmount
    ) public {
        SimpleContract simpleContract = new SimpleContract();

        address user = address(simpleContract);

        uint256 depositAmount = bound(_depositAmount, 1e18, 1e73);
        uint256 withdrawAmount = bound(_withdrawAmount, 1e18, depositAmount);

        deal(user, depositAmount * bound(_multiplier, 1, 10));

        vm.startPrank(user, user);
        holdingManager.createHolding();
        holdingManager.wrapAndDeposit{ value: depositAmount }();

        vm.expectRevert(bytes("3016"));
        holdingManager.withdrawAndUnwrap(withdrawAmount);
        vm.stopPrank();
    }

    // Tests if borrowMultiple reverts correctly when caller doesn't have holding in the system
    function test_borrowMultiple_when_invalidHolding(
        address _user
    ) public {
        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.borrowMultiple(data, false);
    }

    // Tests if borrowMultiple reverts correctly when no collateral data is provided
    function test_borrowMultiple_when_noData() public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.startPrank(user, user);
        holdingManager.createHolding();
        vm.expectRevert(bytes("3006"));
        holdingManager.borrowMultiple(data, false);
        vm.stopPrank();
    }

    // Tests if borrowMultiple reverts correctly when contract is paused
    function test_borrowMultiple_when_paused() public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.prank(user, user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(user, user);
        vm.expectRevert();
        holdingManager.borrowMultiple(data, false);
    }

    // Tests if borrowMultiple works correctly when authorized
    function test_borrowMultiple_when_authorized(address _user, uint256 _usdcAmount, uint256 _wEthAmount) public {
        vm.assume(_user != address(0));

        uint256 usdcAmount = bound(_usdcAmount, 2, 50_000 * 10 ** usdc.decimals());
        uint256 wEthAmount = bound(_wEthAmount, 2, 50_000 * 10 ** weth.decimals());

        deal(address(usdc), _user, usdcAmount);
        deal(address(weth), _user, wEthAmount);

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();

        usdc.approve(address(holdingManager), usdcAmount);
        weth.approve(address(holdingManager), wEthAmount);

        holdingManager.deposit(address(usdc), usdcAmount);
        holdingManager.deposit(address(weth), wEthAmount);

        IHoldingManager.BorrowOrRepayData[] memory data = new IHoldingManager.BorrowOrRepayData[](2);
        data[0] = IHoldingManager.BorrowOrRepayData(address(usdc), usdcAmount / 2);
        data[1] = IHoldingManager.BorrowOrRepayData(address(weth), wEthAmount / 2);

        vm.expectEmit();
        emit Borrowed(holding, address(usdc), usdcAmount / 2, true);
        emit Borrowed(holding, address(weth), wEthAmount / 2, true);
        emit BorrowedMultiple(holding, data.length, true);

        holdingManager.borrowMultiple(data, true);
        vm.stopPrank();

        assertEq(jUsd.balanceOf(_user), usdcAmount / 2 + wEthAmount / 2, "jUSD amount incorrect after borrowMultiple");
        assertEq(
            ISharesRegistry(registries[address(weth)]).borrowed(holding),
            wEthAmount / 2,
            "wETH registry didn't track user's borrow operation"
        );
        assertEq(
            ISharesRegistry(registries[address(usdc)]).borrowed(holding),
            usdcAmount / 2,
            "USDC registry didn't track user's borrow operation"
        );
    }

    // Tests if repayMultiple reverts correctly when caller doesn't have holding in the system
    function test_repayMultiple_when_invalidHolding(
        address _user
    ) public {
        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.repayMultiple(data, false);
    }

    // Tests if repayMultiple reverts correctly when no collateral data is provided
    function test_repayMultiple_when_noData() public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.startPrank(user, user);
        holdingManager.createHolding();
        vm.expectRevert(bytes("3006"));
        holdingManager.repayMultiple(data, false);
        vm.stopPrank();
    }

    // Tests if repayMultiple reverts correctly when contract is paused
    function test_repayMultiple_when_paused() public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        IHoldingManager.BorrowOrRepayData[] memory data;

        vm.prank(user, user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(user, user);
        vm.expectRevert();
        holdingManager.repayMultiple(data, false);
    }

    // Tests if repayMultiple works correctly when authorized
    function test_repayMultiple_when_authorized(address _user, uint256 _usdcAmount, uint256 _wEthAmount) public {
        vm.assume(_user != address(0));

        uint256 usdcAmount = bound(_usdcAmount, 2, 50_000 * 10 ** usdc.decimals());
        uint256 wEthAmount = bound(_wEthAmount, 2, 50_000 * 10 ** weth.decimals());

        deal(address(usdc), _user, usdcAmount);
        deal(address(weth), _user, wEthAmount);

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();

        usdc.approve(address(holdingManager), usdcAmount);
        weth.approve(address(holdingManager), wEthAmount);

        holdingManager.deposit(address(usdc), usdcAmount);
        holdingManager.deposit(address(weth), wEthAmount);

        IHoldingManager.BorrowOrRepayData[] memory data = new IHoldingManager.BorrowOrRepayData[](2);
        data[0] = IHoldingManager.BorrowOrRepayData(address(usdc), usdcAmount / 2);
        data[1] = IHoldingManager.BorrowOrRepayData(address(weth), wEthAmount / 2);

        holdingManager.borrowMultiple(data, true);

        vm.expectEmit();
        emit Repaid(holding, address(usdc), usdcAmount / 2, true);
        emit Repaid(holding, address(weth), wEthAmount / 2, true);
        emit RepaidMultiple(holding, data.length, true);

        holdingManager.repayMultiple(data, true);

        holdingManager.withdraw(address(usdc), usdcAmount);
        holdingManager.withdraw(address(weth), wEthAmount);

        vm.stopPrank();

        assertEq(jUsd.balanceOf(_user), 0, "jUSD wasn't taken from user after repayMultiple");
        assertEq(
            ISharesRegistry(registries[address(weth)]).borrowed(holding),
            0,
            "wETH registry didn't track user's repay operation"
        );
        assertEq(
            ISharesRegistry(registries[address(usdc)]).borrowed(holding),
            0,
            "USDC registry didn't track user's repay operation"
        );
        assertEq(weth.balanceOf(_user), wEthAmount, "User wasn't able to withdraw wETH after repay operation");
        assertEq(usdc.balanceOf(_user), usdcAmount, "User wasn't able to withdraw USDC after repay operation");
    }

    // Tests if repay reverts correctly when contract is paused
    function test_repay_when_paused() public {
        address user = address(uint160(uint256(keccak256(bytes("Random user")))));

        vm.prank(user, user);
        holdingManager.createHolding();

        vm.prank(holdingManager.owner(), holdingManager.owner());
        holdingManager.pause();

        vm.prank(user, user);
        vm.expectRevert();
        holdingManager.repay(address(1), 1, true);
    }

    // Tests if repay reverts correctly when caller doesn't have holding in the system
    function test_repay_when_invalidHolding(
        address _user
    ) public {
        vm.prank(_user, _user);
        vm.expectRevert(bytes("3002"));
        holdingManager.repay(address(1), 1, true);
    }

    // Tests if repay works correctly when authorized
    function test_repay_when_authorized(address _user, uint256 _usdcAmount) public {
        vm.assume(_user != address(0));

        uint256 usdcAmount = bound(_usdcAmount, 2, 50_000 * 10 ** usdc.decimals());

        deal(address(usdc), _user, usdcAmount);

        vm.startPrank(_user, _user);
        address holding = holdingManager.createHolding();
        usdc.approve(address(holdingManager), usdcAmount);
        holdingManager.deposit(address(usdc), usdcAmount);
        holdingManager.borrow(address(usdc), usdcAmount / 2, true);

        vm.expectEmit();
        emit Repaid(holding, address(usdc), usdcAmount / 2, true);
        holdingManager.repay(address(usdc), usdcAmount / 2, true);

        holdingManager.withdraw(address(usdc), usdcAmount);

        vm.stopPrank();

        assertEq(jUsd.balanceOf(_user), 0, "jUSD wasn't taken from user after repayMultiple");
        assertEq(
            ISharesRegistry(registries[address(usdc)]).borrowed(holding),
            0,
            "USDC registry didn't track user's repay operation"
        );
        assertEq(usdc.balanceOf(_user), usdcAmount, "User wasn't able to withdraw USDC after repay operation");
    }
}
