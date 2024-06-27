// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Manager } from "../../src/Manager.sol";
import { OperationsLib } from "../../src/libraries/OperationsLib.sol";
import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";

contract ManagerTest is BasicContractsFixture {
    event DexManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event SwapManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event LiquidationManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event StrategyManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event HoldingManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event StablecoinManagerUpdated(address indexed oldAddress, address indexed newAddress);
    event ProtocolTokenUpdated(address indexed oldAddress, address indexed newAddress);
    event FeeAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event StabilityPoolAddressUpdated(address indexed oldAddress, address indexed newAddress);
    event PerformanceFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event ReceiptTokenFactoryUpdated(address indexed oldAddress, address indexed newAddress);
    event LiquidityGaugeFactoryUpdated(address indexed oldAddress, address indexed newAddress);
    event LiquidatorBonusUpdated(uint256 oldAmount, uint256 newAmount);
    event SelfLiquidationFeeUpdated(uint256 oldAmount, uint256 newAmount);
    event VaultUpdated(address indexed oldAddress, address indexed newAddress);
    event WithdrawalFeeUpdated(uint256 indexed oldFee, uint256 indexed newFee);
    event ContractWhitelisted(address indexed contractAddress);
    event ContractBlacklisted(address indexed contractAddress);
    event TokenWhitelisted(address indexed token);
    event TokenRemoved(address indexed token);
    event NonWithdrawableTokenAdded(address indexed token);
    event NonWithdrawableTokenRemoved(address indexed token);
    event InvokerUpdated(address indexed component, bool allowed);

    function setUp() public {
        init();
    }

    function test_should_set_liquidator_bonus(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 validAmount = bound(_amount, 0, manager.PRECISION() - 1);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setLiquidatorBonus(validAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldLiquidatorBonus = manager.liquidatorBonus();
        vm.expectEmit(true, true, false, false);
        emit LiquidatorBonusUpdated(oldLiquidatorBonus, validAmount);
        manager.setLiquidatorBonus(validAmount);
        assertEq(manager.liquidatorBonus(), validAmount);

        uint256 PRECISION = manager.PRECISION();
        vm.expectRevert(bytes("3066"));
        manager.setLiquidatorBonus(PRECISION + 1000);
    }

    function test_should_set_self_liquidation_fee(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 newAmount = bound(_amount, 0, manager.PRECISION() - 1);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setSelfLiquidationFee(newAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldAmount = manager.selfLiquidationFee();
        vm.expectEmit(true, true, false, false);
        emit SelfLiquidationFeeUpdated(oldAmount, newAmount);
        manager.setSelfLiquidationFee(newAmount);
        assertEq(manager.selfLiquidationFee(), newAmount);
    }

    function test_should_set_fee_address(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.feeAddress());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setFeeAddress(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setFeeAddress(address(0));

        vm.expectEmit(true, true, false, false);
        emit FeeAddressUpdated(manager.feeAddress(), _newAddress);
        manager.setFeeAddress(_newAddress);
        assertEq(manager.feeAddress(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setFeeAddress(_newAddress);
    }

    function test_should_set_liquidation_manager(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.liquidationManager());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setLiquidationManager(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setLiquidationManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit LiquidationManagerUpdated(manager.liquidationManager(), _newAddress);
        manager.setLiquidationManager(_newAddress);
        assertEq(manager.liquidationManager(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setLiquidationManager(_newAddress);
    }

    function test_should_set_strategy_manager(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.strategyManager());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setStrategyManager(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setStrategyManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit StrategyManagerUpdated(manager.strategyManager(), _newAddress);
        manager.setStrategyManager(_newAddress);
        assertEq(manager.strategyManager(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setStrategyManager(_newAddress);
    }

    function test_should_set_swap_manager(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.swapManager());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setSwapManager(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setSwapManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit SwapManagerUpdated(manager.swapManager(), _newAddress);
        manager.setSwapManager(_newAddress);
        assertEq(manager.swapManager(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setSwapManager(_newAddress);
    }

    function test_should_set_holding_manager(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.holdingManager());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setHoldingManager(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setHoldingManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit HoldingManagerUpdated(manager.holdingManager(), _newAddress);
        manager.setHoldingManager(_newAddress);
        assertEq(manager.holdingManager(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setHoldingManager(_newAddress);
    }

    function test_should_set_stable_coin_manager(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.stablesManager());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setStablecoinManager(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setStablecoinManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit StablecoinManagerUpdated(manager.stablesManager(), _newAddress);
        manager.setStablecoinManager(_newAddress);
        assertEq(manager.stablesManager(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setStablecoinManager(_newAddress);
    }

    function test_should_set_performance_fee(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 newAmount = bound(_amount, 1, OperationsLib.FEE_FACTOR - 1);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setPerformanceFee(newAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldAmount = manager.performanceFee();
        vm.expectEmit(true, true, false, false);
        emit PerformanceFeeUpdated(oldAmount, newAmount);
        manager.setPerformanceFee(newAmount);
        assertEq(manager.performanceFee(), newAmount);

        vm.expectRevert(bytes("3018"));
        manager.setPerformanceFee(OperationsLib.FEE_FACTOR + 1000);

        vm.expectRevert(bytes("2001"));
        manager.setPerformanceFee(0);
    }

    function test_should_set_withdrawal_fee(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 newAmount = bound(_amount, 1, OperationsLib.FEE_FACTOR - 1);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setWithdrawalFee(newAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldAmount = manager.withdrawalFee();
        vm.expectEmit(true, true, false, false);
        emit WithdrawalFeeUpdated(oldAmount, newAmount);
        manager.setWithdrawalFee(newAmount);
        assertEq(manager.withdrawalFee(), newAmount);

        vm.expectRevert(bytes("2066"));
        manager.setWithdrawalFee(OperationsLib.FEE_FACTOR + 1000);

        vm.expectRevert(bytes("3017"));
        manager.setWithdrawalFee(newAmount);
    }

    function test_should_set_receipt_token_factory(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.receiptTokenFactory());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setReceiptTokenFactory(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setReceiptTokenFactory(address(0));

        vm.expectEmit(true, true, false, false);
        emit ReceiptTokenFactoryUpdated(manager.receiptTokenFactory(), _newAddress);
        manager.setReceiptTokenFactory(_newAddress);
        assertEq(manager.receiptTokenFactory(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setReceiptTokenFactory(_newAddress);
    }

    function test_should_set_liquidity_gauge_factory(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_newAddress != manager.liquidityGaugeFactory());

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.setLiquidityGaugeFactory(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setLiquidityGaugeFactory(address(0));

        vm.expectEmit(true, true, false, false);
        emit LiquidityGaugeFactoryUpdated(manager.liquidityGaugeFactory(), _newAddress);
        manager.setLiquidityGaugeFactory(_newAddress);
        assertEq(manager.liquidityGaugeFactory(), _newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setLiquidityGaugeFactory(_newAddress);
    }

    function test_should_whitelist_contract(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(manager.isContractWhitelisted(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.whitelistContract(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.whitelistContract(address(0));

        vm.expectEmit(true, false, false, false);
        emit ContractWhitelisted(_newAddress);
        manager.whitelistContract(_newAddress);
        assertTrue(manager.isContractWhitelisted(_newAddress));

        vm.expectRevert(bytes("3019"));
        manager.whitelistContract(_newAddress);
    }

    function test_should_blacklist_contract(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(manager.isContractWhitelisted(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.blacklistContract(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.blacklistContract(address(0));

        manager.whitelistContract(_newAddress);
        assertTrue(manager.isContractWhitelisted(_newAddress));

        vm.expectEmit(true, false, false, false);
        emit ContractBlacklisted(_newAddress);
        manager.blacklistContract(_newAddress);
        assertFalse(manager.isContractWhitelisted(_newAddress));

        vm.expectRevert(bytes("1000"));
        manager.blacklistContract(_newAddress);
    }

    function test_should_whitelist_token(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(manager.isTokenWhitelisted(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.whitelistToken(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.whitelistToken(address(0));

        vm.expectEmit(true, false, false, false);
        emit TokenWhitelisted(_newAddress);
        manager.whitelistToken(_newAddress);
        assertTrue(manager.isTokenWhitelisted(_newAddress));

        vm.expectRevert(bytes("3019"));
        manager.whitelistToken(_newAddress);
    }

    function test_should_remove_token(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(manager.isTokenWhitelisted(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.removeToken(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.removeToken(address(0));

        manager.whitelistToken(_newAddress);
        assertTrue(manager.isTokenWhitelisted(_newAddress));

        vm.expectEmit(true, false, false, false);
        emit TokenRemoved(_newAddress);
        manager.removeToken(_newAddress);
        assertFalse(manager.isTokenWhitelisted(_newAddress));

        vm.expectRevert(bytes("1000"));
        manager.removeToken(_newAddress);
    }

    function test_should_add_non_withdrawable_token(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(_user != address(strategyManager));
        vm.assume(manager.isTokenNonWithdrawable(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("1000"));
        manager.addNonWithdrawableToken(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.addNonWithdrawableToken(address(0));

        vm.expectEmit(true, false, false, false);
        emit NonWithdrawableTokenAdded(_newAddress);
        manager.addNonWithdrawableToken(_newAddress);
        assertTrue(manager.isTokenNonWithdrawable(_newAddress));

        vm.expectRevert(bytes("3069"));
        manager.addNonWithdrawableToken(_newAddress);
    }

    function test_should_remove_non_withdrawable_token(address _user, address _newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(_newAddress != address(0));
        vm.assume(manager.isTokenNonWithdrawable(_newAddress) == false);

        vm.prank(_user);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        manager.removeNonWithdrawableToken(_newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.removeNonWithdrawableToken(address(0));

        manager.addNonWithdrawableToken(_newAddress);
        assertTrue(manager.isTokenNonWithdrawable(_newAddress));

        vm.expectEmit(true, false, false, false);
        emit NonWithdrawableTokenRemoved(_newAddress);
        manager.removeNonWithdrawableToken(_newAddress);
        assertFalse(manager.isTokenNonWithdrawable(_newAddress));

        vm.expectRevert(bytes("3070"));
        manager.removeNonWithdrawableToken(_newAddress);
    }

    function test_should_not_renounce_ownership() public {
        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("1000"));
        manager.renounceOwnership();
    }
}
