// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { Manager } from "../../src/Manager.sol";
import { OperationsLib } from "../../src/libraries/OperationsLib.sol";
import "../fixtures/BasicContractsFixture.t.sol";

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
    event WithdrawableTokenAdded(address indexed token);
    event WithdrawableTokenRemoved(address indexed token);
    event InvokerUpdated(address indexed component, bool allowed);
    event OracleUpdated(address indexed oldOracle, address indexed newOracle);
    event OracleDataUpdated(bytes indexed oldData, bytes indexed newData);
    event TimelockAmountUpdateRequested(uint256 oldVal, uint256 newVal);
    event TimelockAmountUpdated(uint256 oldVal, uint256 newVal);
    event NewLiquidationManagerRequested(address indexed oldAddress, address indexed newAddress);
    event NewSwapManagerRequested(address indexed oldAddress, address indexed newAddress);

    function setUp() public {
        init();
    }

    function test_should_set_fee_address(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.feeAddress());

        vm.prank(_user);
        vm.expectRevert();
        manager.setFeeAddress(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setFeeAddress(address(0));

        vm.expectEmit(true, true, false, false);
        emit FeeAddressUpdated(manager.feeAddress(), newAddress);
        manager.setFeeAddress(newAddress);
        assertEq(manager.feeAddress(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setFeeAddress(newAddress);
    }

    function test_should_set_liquidation_manager(address _user, address newAddress, address _anotherAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.liquidationManager());
        vm.assume(_anotherAddress != newAddress);
        vm.assume(_anotherAddress != address(0));

        // imitate fresh state of the contract
        vm.store(address(manager), bytes32(uint256(9)), bytes32(abi.encode(address(0))));

        vm.prank(_user);
        vm.expectRevert();
        manager.setLiquidationManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setLiquidationManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit LiquidationManagerUpdated(manager.liquidationManager(), newAddress);
        manager.setLiquidationManager(newAddress);
        assertEq(manager.liquidationManager(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setLiquidationManager(_anotherAddress);
    }

    function test_should_set_strategy_manager(address _user, address newAddress, address _anotherAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.strategyManager());
        vm.assume(_anotherAddress != newAddress);
        vm.assume(_anotherAddress != address(0));

        // imitate fresh state of the contract
        vm.store(address(manager), bytes32(uint256(11)), bytes32(abi.encode(address(0))));

        vm.prank(_user);
        vm.expectRevert();
        manager.setStrategyManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setStrategyManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit StrategyManagerUpdated(manager.strategyManager(), newAddress);
        manager.setStrategyManager(newAddress);
        assertEq(manager.strategyManager(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setStrategyManager(_anotherAddress);
    }

    function test_should_set_swap_manager(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.swapManager());

        vm.prank(_user);
        vm.expectRevert();
        manager.setSwapManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setSwapManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit SwapManagerUpdated(manager.swapManager(), newAddress);
        manager.setSwapManager(newAddress);
        assertEq(manager.swapManager(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setSwapManager(newAddress);
    }

    function test_should_set_holding_manager(address _user, address newAddress, address _anotherAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.holdingManager());
        vm.assume(_anotherAddress != newAddress);
        vm.assume(_anotherAddress != address(0));

        // imitate fresh state of the contract
        vm.store(address(manager), bytes32(uint256(8)), bytes32(abi.encode(address(0))));

        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("3000"));
        manager.setHoldingManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit HoldingManagerUpdated(manager.holdingManager(), newAddress);
        manager.setHoldingManager(newAddress);
        assertEq(manager.holdingManager(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setHoldingManager(_anotherAddress);
    }

    function test_should_set_stables_manager(address _user, address newAddress, address _anotherAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.stablesManager());
        vm.assume(_anotherAddress != newAddress);
        vm.assume(_anotherAddress != address(0));

        // imitate fresh state of the contract
        vm.store(address(manager), bytes32(uint256(10)), bytes32(abi.encode(address(0))));

        vm.prank(_user);
        vm.expectRevert();
        manager.setStablecoinManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setStablecoinManager(address(0));

        vm.expectEmit(true, true, false, false);
        emit StablecoinManagerUpdated(manager.stablesManager(), newAddress);
        manager.setStablecoinManager(newAddress);
        assertEq(manager.stablesManager(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setStablecoinManager(_anotherAddress);
    }

    function test_should_set_performance_fee(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 maxFee = manager.MAX_PERFORMANCE_FEE();
        uint256 newAmount = bound(_amount, 1, maxFee - 1);

        vm.prank(_user);
        vm.expectRevert();
        manager.setPerformanceFee(newAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldAmount = manager.performanceFee();
        vm.expectEmit(true, true, false, false);
        emit PerformanceFeeUpdated(oldAmount, newAmount);
        manager.setPerformanceFee(newAmount);
        assertEq(manager.performanceFee(), newAmount);

        vm.expectRevert(bytes("3018"));
        manager.setPerformanceFee(maxFee + 1000);

        // Should set 0 fee
        manager.setPerformanceFee(0);
        assertEq(manager.performanceFee(), 0);
    }

    function test_should_set_withdrawal_fee(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 maxFee = manager.MAX_WITHDRAWAL_FEE();
        uint256 newAmount = bound(_amount, 1, maxFee - 1);

        vm.prank(_user);
        vm.expectRevert();
        manager.setWithdrawalFee(newAmount);

        vm.startPrank(OWNER, OWNER);
        uint256 oldAmount = manager.withdrawalFee();
        vm.expectEmit(true, true, false, false);
        emit WithdrawalFeeUpdated(oldAmount, newAmount);
        manager.setWithdrawalFee(newAmount);
        assertEq(manager.withdrawalFee(), newAmount);

        vm.expectRevert(bytes("3018"));
        manager.setWithdrawalFee(maxFee + 1000);

        vm.expectRevert(bytes("3017"));
        manager.setWithdrawalFee(newAmount);
    }

    function test_should_set_receipt_token_factory(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != manager.receiptTokenFactory());

        vm.prank(_user);
        vm.expectRevert();
        manager.setReceiptTokenFactory(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.setReceiptTokenFactory(address(0));

        vm.expectEmit(true, true, false, false);
        emit ReceiptTokenFactoryUpdated(manager.receiptTokenFactory(), newAddress);
        manager.setReceiptTokenFactory(newAddress);
        assertEq(manager.receiptTokenFactory(), newAddress);

        vm.expectRevert(bytes("3017"));
        manager.setReceiptTokenFactory(newAddress);
    }

    function test_should_whitelist_contract(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(manager.isContractWhitelisted(newAddress) == false);

        vm.prank(_user);
        vm.expectRevert();
        manager.whitelistContract(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.whitelistContract(address(0));

        vm.expectEmit(true, false, false, false);
        emit ContractWhitelisted(newAddress);
        manager.whitelistContract(newAddress);
        assertTrue(manager.isContractWhitelisted(newAddress));

        vm.expectRevert(bytes("3019"));
        manager.whitelistContract(newAddress);
    }

    function test_should_blacklist_contract(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(manager.isContractWhitelisted(newAddress) == false);

        vm.prank(_user);
        vm.expectRevert();
        manager.blacklistContract(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.blacklistContract(address(0));

        manager.whitelistContract(newAddress);
        assertTrue(manager.isContractWhitelisted(newAddress));

        vm.expectEmit(true, false, false, false);
        emit ContractBlacklisted(newAddress);
        manager.blacklistContract(newAddress);
        assertFalse(manager.isContractWhitelisted(newAddress));

        vm.expectRevert(bytes("1000"));
        manager.blacklistContract(newAddress);
    }

    function test_should_whitelist_token(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(manager.isTokenWhitelisted(newAddress) == false);

        vm.prank(_user);
        vm.expectRevert();
        manager.whitelistToken(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.whitelistToken(address(0));

        vm.expectEmit(true, false, false, false);
        emit TokenWhitelisted(newAddress);
        manager.whitelistToken(newAddress);
        assertTrue(manager.isTokenWhitelisted(newAddress));

        vm.expectRevert(bytes("3019"));
        manager.whitelistToken(newAddress);
    }

    function test_should_remove_token(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(manager.isTokenWhitelisted(newAddress) == false);

        vm.prank(_user);
        vm.expectRevert();
        manager.removeToken(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.removeToken(address(0));

        manager.whitelistToken(newAddress);
        assertTrue(manager.isTokenWhitelisted(newAddress));

        vm.expectEmit(true, false, false, false);
        emit TokenRemoved(newAddress);
        manager.removeToken(newAddress);
        assertFalse(manager.isTokenWhitelisted(newAddress));

        vm.expectRevert(bytes("1000"));
        manager.removeToken(newAddress);
    }

    function test_should_add_withdrawable_token(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(_user != address(strategyManager));
        vm.assume(manager.isTokenWithdrawable(newAddress) == false);

        vm.expectRevert(bytes("1000"));
        manager.addWithdrawableToken(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.addWithdrawableToken(address(0));

        vm.expectEmit(true, false, false, false);
        emit WithdrawableTokenAdded(newAddress);
        manager.addWithdrawableToken(newAddress);
        assertTrue(manager.isTokenWithdrawable(newAddress));

        vm.expectRevert(bytes("3069"));
        manager.addWithdrawableToken(newAddress);
    }

    function test_should_remove_withdrawable_token(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        vm.assume(newAddress != address(0));
        vm.assume(manager.isTokenWithdrawable(newAddress) == false);

        vm.prank(_user);
        vm.expectRevert();
        manager.removeWithdrawableToken(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.removeWithdrawableToken(address(0));

        manager.addWithdrawableToken(newAddress);
        assertTrue(manager.isTokenWithdrawable(newAddress));

        vm.expectEmit(true, false, false, false);
        emit WithdrawableTokenRemoved(newAddress);
        manager.removeWithdrawableToken(newAddress);
        assertFalse(manager.isTokenWithdrawable(newAddress));

        vm.expectRevert(bytes("3070"));
        manager.removeWithdrawableToken(newAddress);
    }

    function test_requestNewJUsdOracle_when_alreadyRequested() public {
        vm.startPrank(OWNER, OWNER);

        address oldOracle = address(manager.jUsdOracle());
        vm.expectRevert(bytes("3017"));
        manager.requestNewJUsdOracle(oldOracle);

        manager.requestNewJUsdOracle(address(1));

        vm.expectRevert(bytes("3017"));
        manager.requestNewJUsdOracle(address(1));
    }

    function test_setJUsdOracle_when_reverts() public {
        // Test case when oracle is not requested
        vm.startPrank(OWNER, OWNER);
        vm.expectRevert(bytes("3063"));
        manager.acceptNewJUsdOracle();

        // Test case when setting too early
        manager.requestNewJUsdOracle(address(1));
        vm.expectRevert(bytes("3066"));
        manager.acceptNewJUsdOracle();
    }

    function test_setJUsdOracleData() public {
        // Test case when oracle data is the same
        vm.startPrank(OWNER, OWNER);
        bytes memory oldData = manager.oracleData();
        vm.expectRevert(bytes("3017"));
        manager.setJUsdOracleData(oldData);

        // Test happy case
        vm.expectEmit();
        emit OracleDataUpdated(oldData, bytes("New data"));
        manager.setJUsdOracleData(bytes("New data"));
    }

    function test_manager_requestTimelockAmountChanger() public {
        vm.startPrank(OWNER, OWNER);
        uint256 oldTimelock = manager.timelockAmount();
        uint256 newTimelock = 100 days;

        // Test case with zero value
        vm.expectRevert(bytes("2001"));
        manager.requestNewTimelock(0);

        // Test authorized request
        vm.expectEmit();
        emit TimelockAmountUpdateRequested(oldTimelock, newTimelock);
        manager.requestNewTimelock(newTimelock);

        // Test request when in active change
        vm.expectRevert(bytes("3017"));
        manager.requestNewTimelock(newTimelock);
    }

    function test_acceptTimelockAmountChange() public {
        vm.startPrank(OWNER, OWNER);

        uint256 oldTimelock = manager.timelockAmount();
        uint256 newTimelock = 1 days;

        // Test accepting request without any request
        vm.expectRevert(bytes("2001"));
        manager.acceptNewTimelock();

        // Make change request
        manager.requestNewTimelock(newTimelock);

        // Test accepting request too early
        vm.expectRevert(bytes("3066"));
        manager.acceptNewTimelock();

        // Test authorized accept
        vm.warp(block.timestamp + oldTimelock);
        vm.expectEmit();
        emit TimelockAmountUpdated(oldTimelock, newTimelock);
        manager.acceptNewTimelock();

        assertEq(manager.timelockAmount(), newTimelock, "Timelock amount set wrong");
    }

    function test_getJUsdExchangeRate_when_notUpdated() public {
        // Test case when rate is 0
        jUsdOracle.setRateTo0();
        vm.expectRevert(bytes("2100"));
        manager.getJUsdExchangeRate();

        // Test case when rate is not updated
        jUsdOracle.setUpdatedToFalse();
        vm.expectRevert(bytes("3037"));
        manager.getJUsdExchangeRate();
    }

    function test_should_not_renounce_ownership() public {
        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("1000"));
        Manager(address(manager)).renounceOwnership();
    }

    function test_should_request_new_liquidation_manager(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldLiquidationManager = manager.liquidationManager();

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldLiquidationManager);

        vm.prank(_user);
        vm.expectRevert();
        manager.requestNewLiquidationManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.requestNewLiquidationManager(address(0));

        vm.expectRevert(bytes("3017"));
        manager.requestNewLiquidationManager(oldLiquidationManager);

        assertEq(manager.newLiquidationManager(), address(0));
        assertEq(manager.newLiquidationManagerTimestamp(), 0);

        vm.expectEmit(true, true, false, false);
        emit NewLiquidationManagerRequested(oldLiquidationManager, newAddress);
        manager.requestNewLiquidationManager(newAddress);
        assertEq(manager.newLiquidationManager(), newAddress);
        assertEq(manager.newLiquidationManagerTimestamp(), block.timestamp);
    }

    function test_should_accept_new_liquidation_manager(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldLiquidationManager = manager.liquidationManager();
        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldLiquidationManager);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3063"));
        manager.acceptNewLiquidationManager();

        vm.prank(OWNER, OWNER);
        manager.requestNewLiquidationManager(newAddress);

        vm.prank(_user);
        vm.expectRevert();
        manager.acceptNewLiquidationManager();

        // Timelock must expire to allow accept new LiquidationManager
        skip(manager.timelockAmount() + 1 seconds);

        vm.startPrank(OWNER, OWNER);
        vm.expectEmit(true, true, false, false);
        emit LiquidationManagerUpdated(oldLiquidationManager, newAddress);
        manager.acceptNewLiquidationManager();
        assertEq(manager.liquidationManager(), newAddress);
        assertEq(manager.newLiquidationManager(), address(0));
        assertEq(manager.newLiquidationManagerTimestamp(), 0);
    }

    function test_should_not_accept_new_liquidation_manager_due_to_timelock(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldLiquidationManager = manager.liquidationManager();

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldLiquidationManager);

        vm.startPrank(OWNER, OWNER);
        manager.requestNewLiquidationManager(newAddress);

        vm.expectRevert(bytes("3066"));
        manager.acceptNewLiquidationManager();
    }

    function test_should_request_new_swap_manager(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldSwapManager = vm.randomAddress();
        vm.prank(OWNER);
        manager.setSwapManager(oldSwapManager);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldSwapManager);

        vm.prank(_user);
        vm.expectRevert();
        manager.requestNewSwapManager(newAddress);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.requestNewSwapManager(address(0));

        vm.expectRevert(bytes("3017"));
        manager.requestNewSwapManager(oldSwapManager);

        assertEq(manager.newSwapManager(), address(0));
        assertEq(manager.newSwapManagerTimestamp(), 0);

        vm.expectEmit(true, true, false, false);
        emit NewSwapManagerRequested(oldSwapManager, newAddress);
        manager.requestNewSwapManager(newAddress);
        assertEq(manager.newSwapManager(), newAddress);
        assertEq(manager.newSwapManagerTimestamp(), block.timestamp);
    }

    function test_should_accept_new_swap_manager(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldSwapManager = vm.randomAddress();
        vm.prank(OWNER);
        manager.setSwapManager(oldSwapManager);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldSwapManager);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3063"));
        manager.acceptNewSwapManager();

        vm.prank(OWNER, OWNER);
        manager.requestNewSwapManager(newAddress);

        vm.prank(_user);
        vm.expectRevert();
        manager.requestNewSwapManager(newAddress);

        // Timelock must expire to allow accept new LiquidationManager
        skip(manager.timelockAmount() + 1 seconds);

        vm.startPrank(OWNER, OWNER);
        vm.expectEmit(true, true, false, false);
        emit SwapManagerUpdated(oldSwapManager, newAddress);
        manager.acceptNewSwapManager();
        assertEq(manager.swapManager(), newAddress);
        assertEq(manager.newSwapManager(), address(0));
        assertEq(manager.newSwapManagerTimestamp(), 0);
    }

    function test_should_not_accept_new_swap_manager_due_to_timelock(address _user, address newAddress) public {
        assumeNotOwnerNotZero(_user);

        address oldSwapManager = vm.randomAddress();
        vm.prank(OWNER);
        manager.setSwapManager(oldSwapManager);

        vm.assume(newAddress != address(0));
        vm.assume(newAddress != oldSwapManager);

        vm.startPrank(OWNER, OWNER);
        manager.requestNewSwapManager(newAddress);

        vm.expectRevert(bytes("3066"));
        manager.acceptNewSwapManager();
    }

    function test_should_set_min_debt_amount(address _user, uint256 _amount) public {
        assumeNotOwnerNotZero(_user);

        uint256 newAmount = bound(_amount, 1, 100_000e18);

        vm.prank(_user);
        vm.expectRevert();
        manager.setMinDebtAmount(newAmount);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("2100"));
        manager.setMinDebtAmount(0);

        uint256 oldAmount = manager.minDebtAmount();

        vm.expectRevert(bytes("3017"));
        manager.setMinDebtAmount(oldAmount);

        manager.setMinDebtAmount(newAmount);
        assertEq(manager.minDebtAmount(), newAmount);
    }

    function test_should_not_set_zero_performance_fee() public {
        vm.startPrank(OWNER);
        uint256 oldFee = manager.performanceFee();
        vm.expectRevert(bytes("3017"));
        manager.setPerformanceFee(oldFee);
    }

    function test_should_update_invoker(
        address _user
    ) public {
        assumeNotOwnerNotZero(_user);

        vm.prank(_user);
        vm.expectRevert();
        manager.updateInvoker(_user, true);

        vm.startPrank(OWNER, OWNER);

        vm.expectRevert(bytes("3000"));
        manager.updateInvoker(address(0), true);

        assertEq(manager.allowedInvokers(_user), false);

        vm.expectEmit(true, true, false, false);
        emit InvokerUpdated(_user, true);
        manager.updateInvoker(_user, true);
        assertEq(manager.allowedInvokers(_user), true);
    }
}
