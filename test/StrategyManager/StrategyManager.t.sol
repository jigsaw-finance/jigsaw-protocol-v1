// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "../fixtures/BasicContractsFixture.t.sol";

import { MaliciousStrategy } from "../utils/mocks/MaliciousStrategy.sol";
import { SampleTokenBigDecimals } from "../utils/mocks/SampleTokenBigDecimals.sol";
import { StrategyWithRewardsMock } from "../utils/mocks/StrategyWithRewardsMock.sol";
import { StrategyWithRewardsYieldsMock } from "../utils/mocks/StrategyWithRewardsYieldsMock.sol";
import { StrategyWithoutRewardsMockBroken } from "../utils/mocks/StrategyWithoutRewardsMockBroken.sol";

contract StrategyManagerTest is BasicContractsFixture {
    using stdMath for int256;

    event StrategyAdded(address indexed strategy);
    event StrategyUpdated(address indexed strategy, bool active, uint256 fee);
    event GaugeAdded(address indexed strategy, address indexed gauge);
    event GaugeRemoved(address indexed strategy);
    event GaugeUpdated(address indexed strategy, address indexed oldGauge, address indexed newGauge);
    event Invested(
        address indexed holding,
        address indexed user,
        address indexed token,
        address strategy,
        uint256 amount,
        uint256 tokenOutResult,
        uint256 tokenInResult
    );
    event InvestmentMoved(
        address indexed holding,
        address indexed user,
        address indexed token,
        address strategyFrom,
        address strategyTo,
        uint256 shares,
        uint256 tokenOutResult,
        uint256 tokenInResult
    );

    event CollateralAdjusted(address indexed holding, address indexed token, uint256 value, bool add);

    function setUp() public {
        init();
    }

    // Tests contract creation with wrong constructor arguments
    function test_wrongConstructorArgs() public {
        vm.expectRevert(bytes("3065"));
        StrategyManager newManager = new StrategyManager(address(this), address(0));
        newManager;
    }

    // Checks if initial state of the contract is correct
    function test_strategyManager_initialState() public {
        assertEq(strategyManager.paused(), false);
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != OWNER);
        vm.startPrank(_caller, _caller);
        vm.expectRevert();

        strategyManager.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        vm.prank(OWNER, OWNER);
        strategyManager.pause();
        assertEq(strategyManager.paused(), true);

        vm.prank(OWNER, OWNER);
        strategyManager.unpause();
        assertEq(strategyManager.paused(), false);
    }

    // Tests adding new strategy to the protocol when unauthorized
    function test_addStrategy_when_unauthorized(
        address _caller
    ) public {
        address strategy = address(uint160(uint256(keccak256("random address"))));
        vm.assume(_caller != OWNER);
        vm.prank(_caller, _caller);
        vm.expectRevert();
        strategyManager.addStrategy(strategy);

        (,, bool whitelisted) = strategyManager.strategyInfo(strategy);
        assertEq(whitelisted, false, "Strategy added when unauthorized");
    }

    // Tests adding new strategy to the protocol when invalid address
    function test_addStrategy_when_invalidAddress() public {
        address strategy = address(0);
        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3000"));
        strategyManager.addStrategy(strategy);

        (,, bool whitelisted) = strategyManager.strategyInfo(strategy);
        assertEq(whitelisted, false, "Strategy added when invalid address");
    }

    // Tests successful addition of the new strategy to the protocol
    function test_addStrategy_when_authorized() public {
        address strategy = address(
            new StrategyWithoutRewardsMock(
                address(manager), address(usdc), address(usdc), address(0), "AnotherMock", "ARM"
            )
        );

        vm.prank(OWNER, OWNER);
        vm.expectEmit();
        emit StrategyAdded(strategy);
        strategyManager.addStrategy(strategy);

        (,, bool whitelisted) = strategyManager.strategyInfo(strategy);
        assertEq(whitelisted, true, "Strategy not added when authorized");
    }

    // Tests adding already existing strategy to the protocol
    function test_addStrategy_when_whitelisted() public {
        address strategy = address(strategyWithoutRewardsMock);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3014"));
        strategyManager.addStrategy(strategy);
    }

    // Tests adding new strategy to the protocol when unauthorized
    function test_updateStrategy_when_unauthorized(
        address _caller
    ) public {
        address strategy = address(uint160(uint256(keccak256("random address"))));
        IStrategyManager.StrategyInfo memory info;

        vm.assume(_caller != OWNER);
        vm.prank(_caller, _caller);
        vm.expectRevert();
        strategyManager.updateStrategy(strategy, info);

        (,, bool whitelisted) = strategyManager.strategyInfo(strategy);
        assertEq(whitelisted, false, "Strategy updated when unauthorized");
    }

    // Tests adding new strategy to the protocol when invalid address
    function test_updateStrategy_when_invalidStrategy() public {
        IStrategyManager.StrategyInfo memory info;
        address strategy = address(0);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3029"));
        strategyManager.updateStrategy(strategy, info);

        (,, bool whitelisted) = strategyManager.strategyInfo(strategy);
        assertEq(whitelisted, false, "Strategy updated when invalid Strategy");
    }

    // Tests successful addition of the new strategy to the protocol
    function test_updateStrategy_when_authorized() public {
        IStrategyManager.StrategyInfo memory info;
        address strategy = address(strategyWithoutRewardsMock);

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3104"));
        strategyManager.updateStrategy(strategy, info);

        info.whitelisted = true;
        info.performanceFee = 100_000_000;

        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3105"));
        strategyManager.updateStrategy(strategy, info);

        info.performanceFee = 3000;

        vm.prank(OWNER, OWNER);
        vm.expectEmit();
        emit StrategyUpdated(strategy, info.active, info.performanceFee);
        strategyManager.updateStrategy(strategy, info);

        (uint256 performanceFee, bool active,) = strategyManager.strategyInfo(strategy);
        assertEq(active, info.active, "Strategy active not updated when authorized");
        assertEq(performanceFee, info.performanceFee, "Strategy performance fee not updated when authorized");
    }

    // Tests if invest function reverts correctly when invalid strategy
    function test_invest_when_invalidStrategy() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        address strategy = address(uint160(uint256(keccak256("random strategy"))));
        uint256 amount = 10e18;

        vm.expectRevert(bytes("3029"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when invalid amount
    function test_invest_when_invalidAmount() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 0;

        vm.expectRevert(bytes("2001"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when invalid token
    function test_invest_when_invalidToken() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 10e18;

        vm.expectRevert(bytes("3001"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when contract is paused
    function test_invest_when_paused() public {
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 10e18;

        vm.prank(OWNER, OWNER);
        strategyManager.pause();

        vm.expectRevert();
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when msg.sender isn't holding
    function test_invest_when_notHolding() public {
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 10e18;

        vm.expectRevert(bytes("3002"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when strategy is inactive
    function test_invest_when_strategyInactive() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 1e18;

        initiateUser(user, address(usdc), amount);

        IStrategyManager.StrategyInfo memory info;
        info.whitelisted = true;
        vm.prank(OWNER, OWNER);
        strategyManager.updateStrategy(strategy, info);

        vm.prank(user, user);
        vm.expectRevert(bytes("1202"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function reverts correctly when token != _strategyStakingToken,
    function test_invest_when_differentTokens(
        uint256 amount
    ) public {
        vm.assume(amount > 0 && amount < 1e20);
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(weth);
        address strategy = address(strategyWithoutRewardsMock);
        initiateUser(user, token, amount);

        vm.prank(user, user);
        vm.expectRevert(bytes("3085"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));
    }

    // Tests if invest function works correctly
    function test_invest_when_authorized(
        uint256 amount
    ) public {
        vm.assume(amount > 0 && amount < 1e20);
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        // uint256 amount = 1e18;

        address holding = initiateUser(user, token, amount);
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);

        vm.prank(user, user);
        vm.expectEmit();
        emit Invested(holding, user, token, strategy, amount, amount, amount);
        strategyManager.invest(token, strategy, amount, 0, bytes(""));

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        assertEq(holdingStrategies.length, 1, "Holding's strategies' count incorrect");
        assertEq(holdingStrategies[0], strategy, "Holding's strategy saved incorrectly");
        assertEq(usdc.balanceOf(holding), holdingBalanceBefore - amount, "Invest didn't transfer holding's funds");
        assertEq(usdc.balanceOf(strategy), amount, "Strategy didn't receive holding's funds");
        assertEq(
            IERC20(address(strategyWithoutRewardsMock.receiptToken())).balanceOf(holding),
            amount,
            "Holding didn't receive receipt tokens"
        );
    }

    // Tests if invest function reverts correctly when strategy is not liquidatable
    function test_invest_when_is_not_liquidatable() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);

        uint256 amount = manager.minDebtAmount() * 2;
        deal(token, user, amount);

        vm.startPrank(user, user);
        address holding = holdingManager.createHolding();
        usdc.approve(address(holdingManager), amount);
        holdingManager.deposit(token, amount);
        holdingManager.borrow(token, amount / 2, 0, true);

        usdcOracle.setPriceForLiquidation();
        vm.expectRevert(bytes("3103"));
        strategyManager.invest(token, strategy, amount / 2, 0, bytes(""));
        vm.stopPrank();
    }

    // Tests if claim_investment function reverts correctly when strategy is not liquidatable
    function test_claim_investment_when_is_not_liquidatable() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);

        uint256 amount = manager.minDebtAmount() * 2;
        deal(token, user, amount);

        vm.startPrank(user, user);
        address holding = holdingManager.createHolding();
        usdc.approve(address(holdingManager), amount);
        holdingManager.deposit(token, amount);
        holdingManager.borrow(token, amount / 2, 0, true);

        strategyManager.invest(token, strategy, amount / 2, 0, bytes(""));

        usdcOracle.setPriceForLiquidation();
        vm.expectRevert(bytes("3103"));
        strategyManager.claimInvestment(holding, token, strategy, amount / 2, "");

        vm.stopPrank();
    }

    // Tests if invest function reverts correctly when strategy returns tokenOutAmount as 0
    function test_invest_when_tokenOutAmount0(
        uint256 amount
    ) public {
        vm.assume(amount > 0 && amount < 1e20);
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(weth);

        vm.startPrank(OWNER, OWNER);
        StrategyWithoutRewardsMockBroken strategyWithoutRewardsMockBroken = new StrategyWithoutRewardsMockBroken(
            address(manager), address(weth), address(weth), address(0), "Broken-Mock", "BRM"
        );
        strategyManager.addStrategy(address(strategyWithoutRewardsMockBroken));
        vm.stopPrank();

        address strategy = address(strategyWithoutRewardsMockBroken);
        address holding = initiateUser(user, token, amount);

        vm.prank(user, user);
        vm.expectRevert(bytes("3030"));
        strategyManager.invest(token, strategy, amount, 0, bytes(""));

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        assertEq(holdingStrategies.length, 0, "Holding's strategies' count incorrect");
        assertEq(
            IERC20(address(strategyWithoutRewardsMock.receiptToken())).balanceOf(holding),
            0,
            "Holding wrongfully received receipt tokens"
        );
    }

    // Tests if moveInvestment function reverts correctly when invalid strategyFrom
    function test_moveInvestment_when_invalidStrategyFrom() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        IStrategyManager.MoveInvestmentData memory moveInvestmentData;

        vm.expectRevert(bytes("3029"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when invalid strategyTo
    function test_moveInvestment_when_invalidStrategyTo() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyWithoutRewardsMock);

        vm.expectRevert(bytes("3029"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when contract is paused
    function test_moveInvestment_when_paused() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyWithoutRewardsMock);
        moveInvestmentData.strategyTo = address(strategyWithoutRewardsMock);

        vm.prank(OWNER, OWNER);
        strategyManager.pause();

        vm.expectRevert();
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when msg.sender has no holding
    function test_moveInvestment_when_notHolding() public {
        address token = address(uint160(uint256(keccak256("random token"))));
        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyWithoutRewardsMock);
        moveInvestmentData.strategyTo = address(strategyWithoutRewardsMock);

        vm.expectRevert(bytes("3002"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when strategyTo and strategyFrom are the same
    function test_moveInvestment_when_sameStrategies() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 1e18;

        initiateUser(user, address(usdc), amount);

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = strategy;
        moveInvestmentData.strategyTo = strategy;

        vm.prank(user, user);
        vm.expectRevert(bytes("3086"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when token is strategy's tokenIn
    function test_moveInvestment_when_token_is_strategy_from_token_in() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(weth);
        uint256 amount = 1e18;

        vm.startPrank(OWNER, OWNER);
        StrategyWithoutRewardsMockBroken strategyFrom = new StrategyWithoutRewardsMockBroken(
            address(manager), address(usdc), address(weth), address(0), "Broken-Mock", "BRM"
        );
        strategyManager.addStrategy(address(strategyFrom));

        StrategyWithoutRewardsMockBroken strategyTo = new StrategyWithoutRewardsMockBroken(
            address(manager), address(usdc), address(weth), address(0), "Broken-Mock", "BRM"
        );
        strategyManager.addStrategy(address(strategyTo));

        vm.stopPrank();

        initiateUser(user, address(usdc), amount);

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyFrom);
        moveInvestmentData.strategyTo = address(strategyTo);

        vm.prank(user, user);
        vm.expectRevert(bytes("3001"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when token is strategy's tokenIn
    function test_moveInvestment_when_token_is_strategy_to_to_token_in() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(weth);
        uint256 amount = 1e18;

        vm.startPrank(OWNER, OWNER);
        StrategyWithoutRewardsMockBroken strategyFrom = new StrategyWithoutRewardsMockBroken(
            address(manager), address(weth), address(weth), address(0), "Broken-Mock", "BRM"
        );
        strategyManager.addStrategy(address(strategyFrom));

        StrategyWithoutRewardsMockBroken strategyTo = new StrategyWithoutRewardsMockBroken(
            address(manager), address(usdc), address(weth), address(0), "Broken-Mock", "BRM"
        );
        strategyManager.addStrategy(address(strategyTo));

        vm.stopPrank();

        initiateUser(user, address(usdc), amount);

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyFrom);
        moveInvestmentData.strategyTo = address(strategyTo);

        vm.prank(user, user);
        vm.expectRevert(bytes("3085"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if invest function reverts correctly when strategyTo is inactive
    function test_moveInvestment_when_strategyToInactive() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategyTo = address(strategyWithoutRewardsMock);
        uint256 amount = 1e18;

        initiateUser(user, address(usdc), amount);

        IStrategyManager.StrategyInfo memory info;
        info.whitelisted = true;
        vm.prank(OWNER, OWNER);
        strategyManager.updateStrategy(strategyTo, info);

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(
            new StrategyWithoutRewardsMock(
                address(manager), address(usdc), address(usdc), address(0), "AnotherMock", "ARM"
            )
        );
        vm.startPrank(OWNER, OWNER);
        strategyManager.addStrategy(moveInvestmentData.strategyFrom);
        vm.stopPrank();
        moveInvestmentData.strategyTo = strategyTo;

        vm.prank(user, user);
        vm.expectRevert(bytes("1202"));
        strategyManager.moveInvestment(token, moveInvestmentData);
    }

    // Tests if moveInvestment function reverts correctly when claimResult from the strategyFrom is 0
    function test_moveInvestment_when_claimResult0() public {
        vm.startPrank(OWNER, OWNER);
        MaliciousStrategy strategyFrom = new MaliciousStrategy(address(manager), address(usdc), "AnotherMock", "ARM");
        strategyManager.addStrategy(address(strategyFrom));
        vm.stopPrank();

        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        StrategyWithoutRewardsMock strategyTo = strategyWithoutRewardsMock;
        uint256 amount = 1e18;

        address holding = initiateUser(user, address(usdc), amount);

        vm.prank(user, user);
        strategyManager.invest(token, address(strategyFrom), amount, 0, bytes(""));

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyFrom);
        moveInvestmentData.strategyTo = address(strategyTo);
        moveInvestmentData.shares = amount;

        vm.prank(user, user);
        vm.expectRevert(bytes("3016"));
        strategyManager.moveInvestment(token, moveInvestmentData);

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        assertEq(holdingStrategies.length, 1, "Holding's strategies' count incorrect");
        assertEq(holdingStrategies[0], address(strategyFrom), "Holding's strategy saved incorrectly");
        assertEq(usdc.balanceOf(address(strategyFrom)), amount, "strategyFrom wrongfully sent funds");
        assertEq(usdc.balanceOf(address(strategyTo)), 0, "strategyTo wrongfully received funds");
        assertEq(
            IERC20(address(strategyFrom.receiptToken())).balanceOf(holding),
            amount,
            "StrategyFrom receipt tokens incorrect"
        );
        assertEq(
            IERC20(address(strategyTo.receiptToken())).balanceOf(holding), 0, "StrategyTo receipt tokens incorrect"
        );
    }

    // Tests if moveInvestment function works correctly
    function test_moveInvestment_when_authorized() public {
        vm.startPrank(OWNER, OWNER);
        StrategyWithoutRewardsMock strategyTo = new StrategyWithoutRewardsMock(
            address(manager), address(usdc), address(usdc), address(0), "AnotherMock", "ARM"
        );
        strategyManager.addStrategy(address(strategyTo));
        vm.stopPrank();

        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        StrategyWithoutRewardsMock strategyFrom = strategyWithoutRewardsMock;
        uint256 amount = 1e18;

        address holding = initiateUser(user, address(usdc), amount);

        vm.prank(user, user);
        strategyManager.invest(token, address(strategyFrom), amount, 0, bytes(""));

        IStrategyManager.MoveInvestmentData memory moveInvestmentData;
        moveInvestmentData.strategyFrom = address(strategyFrom);
        moveInvestmentData.strategyTo = address(strategyTo);
        moveInvestmentData.shares = amount;

        vm.prank(user, user);
        vm.expectEmit();
        emit InvestmentMoved(
            holding, user, token, moveInvestmentData.strategyFrom, moveInvestmentData.strategyTo, amount, amount, amount
        );
        strategyManager.moveInvestment(token, moveInvestmentData);

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        assertEq(holdingStrategies.length, 1, "Holding's strategies' count incorrect");
        assertEq(holdingStrategies[0], address(strategyTo), "Holding's strategy saved incorrectly");
        assertEq(usdc.balanceOf(address(strategyFrom)), 0, "strategyFrom didn't send funds");
        assertEq(usdc.balanceOf(address(strategyTo)), amount, "strategyTo didn't receive funds");
        assertEq(
            IERC20(address(strategyFrom.receiptToken())).balanceOf(holding), 0, "StrategyFrom receipt tokens incorrect"
        );
        assertEq(
            IERC20(address(strategyTo.receiptToken())).balanceOf(holding), amount, "StrategyTo receipt tokens incorrect"
        );
    }

    // Tests if claimInvestment reverts correctly when invalid strategy address
    function test_claimInvestment_when_invalidStrategy() public {
        address holding = address(0);
        address strategy = address(0);
        uint256 shares = 0;
        address asset = address(0);
        bytes memory data = bytes("");

        vm.expectRevert(bytes("3029"));
        strategyManager.claimInvestment(holding, strategy, asset, shares, data);
    }

    // Tests if claimInvestment reverts correctly when caller is unauthorized
    function test_claimInvestment_when_unauthorized(
        address caller
    ) public {
        address holding = address(0);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 shares = 0;
        address token = address(0);
        bytes memory data = bytes("");

        vm.assume(caller != manager.liquidationManager() && caller != holdingManager.holdingUser(holding));

        vm.expectRevert(bytes("1000"));
        vm.prank(caller, caller);
        strategyManager.claimInvestment(holding, token, strategy, shares, data);
    }

    // Tests if claimInvestment reverts correctly when invalid amount of shares
    function test_claimInvestment_when_invalidAmount() public {
        address holding = address(0);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 shares = 0;
        address token = address(0);
        bytes memory data = bytes("");

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectRevert(bytes("2001"));
        strategyManager.claimInvestment(holding, token, strategy, shares, data);
    }

    // Tests if claimInvestment reverts correctly when paused
    function test_claimInvestment_when_paused() public {
        address holding = address(0);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 shares = 1;
        address asset = address(0);
        bytes memory data = bytes("");

        vm.prank(OWNER, OWNER);
        strategyManager.pause();

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectRevert();
        strategyManager.claimInvestment(holding, strategy, asset, shares, data);
    }

    // Tests if claimInvestment reverts correctly when invalid holding
    function test_claimInvestment_when_notHolding(
        address holding
    ) public {
        address strategy = address(strategyWithoutRewardsMock);
        uint256 shares = 1;
        address token = address(0);
        bytes memory data = bytes("");

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectRevert(bytes("3002"));
        strategyManager.claimInvestment(holding, token, strategy, shares, data);
    }

    // Tests if claimInvestment works  correctly when receiptToken has big decimals
    function test_claimInvestment_when_bigDecimals(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount > 1e6 && amount < 1e20);

        SampleTokenBigDecimals token = new SampleTokenBigDecimals("BDT", "BDT", 0);

        vm.startPrank(OWNER, OWNER);
        manager.whitelistToken(address(token));
        SharesRegistry bdtSharesRegistry = new SharesRegistry(
            msg.sender,
            address(manager),
            address(token),
            address(usdcOracle),
            bytes(""),
            ISharesRegistry.RegistryConfig({
                collateralizationRate: 50_000,
                liquidationBuffer: 5e3,
                liquidatorBonus: 8e3
            })
        );
        stablesManager.registerOrUpdateShareRegistry(address(bdtSharesRegistry), address(token), true);
        vm.stopPrank();

        address holding = initiateUser(user, address(token), amount);

        address strategy = address(
            new StrategyWithRewardsMock(
                address(manager), address(token), address(token), address(0), "RandomToken", "RT"
            )
        );

        address receiptToken = IStrategy(strategy).getReceiptTokenAddress();

        bytes memory data = bytes("");

        vm.startPrank(OWNER, OWNER);
        strategyManager.addStrategy(strategy);
        vm.stopPrank();

        uint256 holdingBalanceBefore = token.balanceOf(holding);

        vm.startPrank(user, user);
        strategyManager.invest(address(token), strategy, holdingBalanceBefore, 0, data);
        uint256 holdingReceiptTokenBalanceAfterInvest = IERC20(receiptToken).balanceOf(holding);

        (, uint256 shares) = IStrategy(strategy).recipients(holding);
        uint256 claimAmount = shares;
        strategyManager.claimInvestment(holding, address(token), strategy, claimAmount, data);
        vm.stopPrank();

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);
        assertEq(holdingStrategies.length, 0, "Holding's strategies' count incorrect");
        assertEq(
            IERC20(receiptToken).balanceOf(holding), shares - claimAmount, "Holding's receipt tokens count incorrect"
        );
        assertEq(IERC20(receiptToken).balanceOf(holding), 0, "Gauge's receipt tokens count incorrect");
        assertEq(token.balanceOf(strategy), shares - claimAmount, "Funds weren't taken from strategy");
        assertEq(token.balanceOf(holding), claimAmount, "Holding didn't receive funds invested in strategy");
    }

    // Tests if claimInvestment works  correctly
    function test_claimInvestment_when_authorized(address user, uint256 amount, uint256 _shares) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0 && amount < 1e20);
        address token = address(usdc);
        address holding = initiateUser(user, token, amount);
        address strategy = address(strategyWithoutRewardsMock);
        bytes memory data = bytes("");
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);

        vm.prank(user, user);
        strategyManager.invest(token, strategy, holdingBalanceBefore, 0, data);
        (, uint256 shares) = strategyWithoutRewardsMock.recipients(holding);
        uint256 claimAmount = bound(_shares, 1, shares);

        vm.prank(user, user);
        strategyManager.claimInvestment(holding, token, strategy, claimAmount, data);

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        (, uint256 remainingShares) = strategyWithoutRewardsMock.recipients(holding);
        if (remainingShares == 0) {
            assertEq(holdingStrategies.length, 0, "Holding's strategies' count incorrect");
        } else {
            assertEq(holdingStrategies.length, 1, "Holding's strategies' count incorrect");
            assertEq(holdingStrategies[0], strategy, "Holding's strategy saved incorrectly");
        }
        assertEq(
            IERC20(address(strategyWithoutRewardsMock.receiptToken())).balanceOf(holding),
            shares - claimAmount,
            "Holding's receipt tokens count incorrect"
        );
        assertEq(usdc.balanceOf(strategy), shares - claimAmount, "Funds weren't taken from strategy");
        assertEq(usdc.balanceOf(holding), claimAmount, "Holding didn't receive funds invested in strategy");
    }

    // Tests if claimInvestment reverts when not enough recipients token
    function test_claimInvestment_revert_when_not_enough_recipients_token(
        address user,
        uint256 amount,
        uint256 _shares
    ) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0 && amount < 1e20);
        address token = address(usdc);
        address holding = initiateUser(user, token, amount);
        address strategy = address(strategyWithoutRewardsMock);
        bytes memory data = bytes("");
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);

        vm.prank(user, user);
        strategyManager.invest(token, strategy, holdingBalanceBefore, 0, data);
        (, uint256 shares) = strategyWithoutRewardsMock.recipients(holding);
        deal(address(strategyWithoutRewardsMock.receiptToken()), holding, 0);

        vm.startPrank(user, user);
        vm.expectRevert();
        strategyManager.claimInvestment(holding, token, strategy, shares, data);
    }

    // Tests if claimInvestment works correctly when yield exists
    function test_claimInvestment_when_yield_and_authorized(
        address user,
        uint256 amount,
        int256 yield,
        uint256 _shares
    ) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0 && amount < 1e20);

        StrategyWithRewardsYieldsMock strategyWithPositiveYield = new StrategyWithRewardsYieldsMock(
            address(manager), address(usdc), address(usdc), address(0), "AnotherMockWithYield", "AMWY"
        );

        vm.prank(OWNER, OWNER);
        strategyManager.addStrategy(address(strategyWithPositiveYield));

        address token = address(usdc);
        address holding = initiateUser(user, token, amount);
        address strategy = address(strategyWithPositiveYield);
        bytes memory data = bytes("");
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);

        vm.prank(user, user);
        strategyManager.invest(token, strategy, holdingBalanceBefore, 0, data);
        (, uint256 shares) = strategyWithPositiveYield.recipients(holding);
        uint256 claimAmount = bound(_shares, 1, shares);

        vm.assume(yield.abs() < claimAmount && yield < 1e20);
        strategyWithPositiveYield.setYield(yield);

        vm.prank(user, user);
        strategyManager.claimInvestment(holding, token, strategy, claimAmount, data);

        address[] memory holdingStrategies = strategyManager.getHoldingToStrategy(holding);

        (, uint256 remainingShares) = strategyWithPositiveYield.recipients(holding);
        if (remainingShares == 0) {
            assertEq(holdingStrategies.length, 0, "Holding's strategies' count incorrect");
        } else {
            assertEq(holdingStrategies.length, 1, "Holding's strategies' count incorrect");
            assertEq(holdingStrategies[0], strategy, "Holding's strategy saved incorrectly");
        }
        assertEq(
            IERC20(address(strategyWithPositiveYield.receiptToken())).balanceOf(holding),
            shares - claimAmount,
            "Holding's receipt tokens count incorrect"
        );

        uint256 totalClaimed = claimAmount;
        if (yield > 0) {
            totalClaimed += yield.abs();
        } else if (yield < 0) {
            totalClaimed -= yield.abs();
        }

        assertEq(usdc.balanceOf(holding), totalClaimed, "Holding didn't receive funds invested in strategy");
    }

    // Tests if claimRewards function reverts correctly when invalidStrategy
    function test_claimRewards_when_invalidStrategy() public {
        address strategy = address(0);
        bytes memory data = bytes("");

        vm.expectRevert(bytes("3029"));
        strategyManager.claimRewards(strategy, data);
    }

    // Tests if claimRewards reverts correctly when paused
    function test_claimRewards_when_paused() public {
        address strategy = address(strategyWithoutRewardsMock);
        bytes memory data = bytes("");

        vm.prank(OWNER, OWNER);
        strategyManager.pause();

        vm.expectRevert();
        strategyManager.claimRewards(strategy, data);
    }

    // Tests if claimRewards reverts correctly when invalid holding
    function test_claimRewards_when_notHolding() public {
        address strategy = address(strategyWithoutRewardsMock);
        bytes memory data = bytes("");

        vm.expectRevert(bytes("3002"));
        strategyManager.claimRewards(strategy, data);
    }

    // Tests if claimRewards works correctly when there are no rewards for the user
    function test_claimRewards_when_noRewards() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        uint256 amount = 10e6;
        address asset = address(usdc);
        initiateUser(user, asset, amount);
        address strategy = address(strategyWithoutRewardsMock);
        bytes memory data = bytes("");

        vm.prank(user, user);
        strategyManager.claimRewards(strategy, data);
    }

    // Tests if claimRewards works correctly when authorized
    function test_claimRewards_when_authorized(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0 && amount < 1e20);
        address asset = address(usdc);
        address holding = initiateUser(user, asset, amount);
        SampleTokenERC20 strategyRewardToken = new SampleTokenERC20("StrategyRewardToken", "SRT", 0);
        address strategy = address(
            new StrategyWithRewardsMock(
                address(manager), address(usdc), address(usdc), address(strategyRewardToken), "RandomToken", "RT"
            )
        );
        bytes memory data = bytes("");
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);
        uint256 holdingRewardBalanceBefore = strategyRewardToken.balanceOf(holding);

        vm.prank(OWNER, OWNER);
        strategyManager.addStrategy(strategy);

        vm.startPrank(user, user);
        strategyManager.invest(asset, strategy, holdingBalanceBefore, 0, data);
        strategyManager.claimRewards(strategy, data);
        vm.stopPrank();

        assertEq(
            strategyRewardToken.balanceOf(holding),
            holdingRewardBalanceBefore + 100 * 10 ** strategyRewardToken.decimals(),
            "Holding didn't receive rewards after claimRewards"
        );
        assertEq(
            SharesRegistry(registries[asset]).collateral(holding),
            holdingBalanceBefore,
            "Holding's collateral amount wrongfully increased after claimRewards"
        );
    }

    // Tests if claimRewards works correctly when the {rewardToken} and {tokenIn} are the same
    function test_claimRewards_when_sameToken(address user, uint256 amount) public {
        vm.assume(user != address(0));
        vm.assume(amount > 0 && amount < 1e20);
        address asset = address(usdc);
        address holding = initiateUser(user, asset, amount);
        uint256 holdingBalanceBefore = usdc.balanceOf(holding);
        SampleTokenERC20 strategyRewardToken = usdc;
        address strategy = address(
            new StrategyWithRewardsMock(
                address(manager), address(usdc), address(usdc), address(strategyRewardToken), "RandomToken", "RT"
            )
        );
        bytes memory data = bytes("");

        vm.prank(OWNER, OWNER);
        strategyManager.addStrategy(strategy);

        vm.startPrank(user, user);
        strategyManager.invest(asset, strategy, holdingBalanceBefore, 0, data);
        vm.expectEmit();
        emit CollateralAdjusted(holding, asset, 100 * 10 ** strategyRewardToken.decimals(), true);
        strategyManager.claimRewards(strategy, data);
        vm.stopPrank();

        assertEq(
            strategyRewardToken.balanceOf(holding),
            100 * 10 ** strategyRewardToken.decimals(),
            "Holding didn't receive rewards after claimRewards"
        );
        assertEq(
            SharesRegistry(registries[asset]).collateral(holding),
            holdingBalanceBefore + 100 * 10 ** strategyRewardToken.decimals(),
            "Holding's collateral amount hasn't increased after claimRewards"
        );
    }

    //Tests if getHoldingToStrategyLength is correct
    function test_getHoldingToStrategyLength() public {
        address user = address(uint160(uint256(keccak256("random user"))));
        address token = address(usdc);
        address strategy = address(strategyWithoutRewardsMock);
        uint256 amount = 1e18;

        address holding = initiateUser(user, token, amount);

        uint256 strategiesCount = strategyManager.getHoldingToStrategyLength(holding);
        assertEq(strategiesCount, 0, "Holding's strategies' count incorrect");

        vm.prank(user, user);
        strategyManager.invest(token, strategy, amount, 0, bytes(""));

        strategiesCount = strategyManager.getHoldingToStrategyLength(holding);
        assertEq(strategiesCount, 1, "Holding's strategies' count incorrect");
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        strategyManager.renounceOwnership();
    }
}
