// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";
import { BasicContractsFixture } from "../fixtures/BasicContractsFixture.t.sol";

contract StablesManagerTest is BasicContractsFixture {
    event AddedCollateral(address indexed holding, address indexed token, uint256 amount);
    event RemovedCollateral(address indexed holding, address indexed token, uint256 amount);
    event ForceRemovedCollateral(address indexed holding, address indexed token, uint256 amount);
    event Borrowed(address indexed holding, uint256 amount, bool mintToUser);
    event Repaid(address indexed holding, uint256 amount, address indexed burnFrom);
    event RegistryAdded(address indexed token, address indexed registry);
    event RegistryUpdated(address indexed token, address indexed registry);
    event RegistryConfigUpdated(address indexed registry, bool active);

    address[] internal allowedCallers;

    function setUp() public {
        init();

        allowedCallers = [manager.strategyManager(), manager.holdingManager(), manager.liquidationManager()];
    }

    // Tests if init fails correctly when manager address is address(0)
    function test_init_when_invalidManager() public {
        vm.expectRevert(bytes("3065"));
        StablesManager failedStablesManager = new StablesManager(address(this), address(0), address(0));
        failedStablesManager;
    }

    // Tests if init works correctly when authorized
    function test_init_when_authorized() public {
        vm.expectRevert(bytes("3001"));
        StablesManager failedStablesManager = new StablesManager(address(this), address(1), address(0));
        failedStablesManager;
    }

    // Tests setting contract paused from non-Owner's address
    function test_setPaused_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != OWNER);
        vm.prank(_caller, _caller);
        vm.expectRevert();

        stablesManager.pause();
    }

    // Tests setting contract paused from Owner's address
    function test_setPaused_when_authorized() public {
        vm.startPrank(OWNER);
        stablesManager.pause();
        assertEq(stablesManager.paused(), true);

        stablesManager.unpause();
        assertEq(stablesManager.paused(), false);
        vm.stopPrank();
    }

    // Tests if registerOrUpdateShareRegistry reverts correctly when caller is unauthorized
    function test_registerOrUpdateShareRegistry_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != OWNER);
        vm.prank(_caller, _caller);
        vm.expectRevert();
        stablesManager.registerOrUpdateShareRegistry(address(1), address(2), true);
    }

    // Tests registerOrUpdateShareRegistry reverts correctly when invalid token address
    function test_registerOrUpdateShareRegistry_when_invalidToken() public {
        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3007"));
        stablesManager.registerOrUpdateShareRegistry(address(1), address(0), true);
    }

    // Tests if registerOrUpdateShareRegistry reverts correctly when invalid registry
    function test_registerOrUpdateShareRegistry_when_invalidRegistry() public {
        vm.prank(OWNER, OWNER);
        vm.expectRevert(bytes("3008"));
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(1), true);
    }

    // Tests if registerOrUpdateShareRegistry works correctly when adding new registry
    function test_registerOrUpdateShareRegistry_when_addNew(address _token, bool _active) public {
        vm.assume(_token != address(0));
        address testRegistry = address(
            new SharesRegistry(
                msg.sender,
                address(manager),
                _token,
                address(1),
                bytes(""),
                ISharesRegistry.RegistryConfig({
                    collateralizationRate: 50_000,
                    liquidationBuffer: 5e3,
                    liquidatorBonus: 8e3
                })
            )
        );

        (, address d) = stablesManager.shareRegistryInfo(_token);
        if (d != address(0)) return;

        vm.prank(OWNER, OWNER);
        vm.expectEmit();
        emit RegistryAdded(_token, testRegistry);
        stablesManager.registerOrUpdateShareRegistry(testRegistry, _token, _active);

        (bool active, address deployedAt) = stablesManager.shareRegistryInfo(_token);

        assertEq(active, _active, "Info.active for registry set incorrectly after adding new registry");
        assertEq(deployedAt, testRegistry, "Info.active for registry set incorrectly after adding new registry");
    }

    // Tests if registerOrUpdateShareRegistry works correctly when updating an existing registry
    function test_registerOrUpdateShareRegistry_when_updateExisting(address _token, bool _active) public {
        vm.assume(_token != address(0));
        address testRegistry = address(
            new SharesRegistry(
                msg.sender,
                address(manager),
                _token,
                address(1),
                bytes(""),
                ISharesRegistry.RegistryConfig({
                    collateralizationRate: 50_000,
                    liquidationBuffer: 5e3,
                    liquidatorBonus: 8e3
                })
            )
        );

        (, address d) = stablesManager.shareRegistryInfo(_token);
        if (d != address(0)) return;

        vm.startPrank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(testRegistry, _token, _active);
        vm.expectEmit();
        emit RegistryUpdated(_token, testRegistry);
        stablesManager.registerOrUpdateShareRegistry(testRegistry, _token, !_active);
        vm.stopPrank();

        (bool active, address deployedAt) = stablesManager.shareRegistryInfo(_token);

        assertEq(active, !_active, "Info.active for registry set incorrectly after updating existing registry");
        assertEq(deployedAt, testRegistry, "Info.active for registry set incorrectly after updating existing registry");
    }

    // Tests if isSolvent reverts correctly when invalid holding address
    function test_isSolvent_when_invalidHolding() public {
        vm.expectRevert(bytes("3031"));
        stablesManager.isSolvent(address(1), address(0));
    }

    // Tests if isSolvent reverts correctly when invalid holding address
    function test_isSolvent_when_noRegistry() public {
        vm.expectRevert(bytes("3008"));
        stablesManager.isSolvent(address(0), address(1));
    }

    // Tests if isSolvent works correctly when borrowed 0
    function test_isSolvent_when_noDebt(
        address _user
    ) public {
        vm.assume(_user != address(0));
        address holding = initiateUser(_user, address(usdc), 10);
        assertEq(stablesManager.isSolvent(address(usdc), holding), true, "isSolvent incorrect when no debt");
    }

    // Tests if isSolvent works correctly when jUSD price is more than $1
    function test_isSolvent_when_expensiveJusd(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);

        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(_user, _user);
        holdingManager.borrow(collateral, _mintAmount, 0, true);

        jUsdOracle.setPrice(2e18);

        assertEq(
            stablesManager.isSolvent(address(usdc), holding), false, "isSolvent incorrect when jUSD price rose to $2"
        );
    }

    // Tests if isSolvent works correctly when jUSD price is less than $1
    function test_isSolvent_when_cheapJusd(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);

        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(_user, _user);
        holdingManager.borrow(collateral, _mintAmount, 0, true);

        jUsdOracle.setPrice(1e7);

        assertEq(
            stablesManager.isSolvent(address(usdc), holding), true, "isSolvent incorrect when jUSD price fell to $0.1"
        );
    }

    // Tests if isSolvent works correctly when jUSD price is less than $1
    function test_isSolvent_when_cheapCollateral(address _user, uint256 _mintAmount) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);

        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(_user, _user);
        holdingManager.borrow(collateral, _mintAmount, 0, true);

        usdcOracle.setPrice(1e7);

        assertEq(
            stablesManager.isSolvent(address(usdc), holding),
            false,
            "isSolvent incorrect when no debt and jUSD price rose to 2$"
        );
    }

    // Tests if addCollateral reverts correctly when paused
    function test_addCollateral_when_paused() public {
        vm.prank(OWNER, OWNER);
        stablesManager.pause();

        vm.expectRevert();
        stablesManager.addCollateral(address(1), address(2), 1);
    }

    // Tests if addCollateral reverts correctly when caller is unauthorized
    function test_addCollateral_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert(bytes("1000"));
        stablesManager.addCollateral(address(1), address(2), 1);
    }

    // Tests if addCollateral reverts correctly when registry inactive
    function test_addCollateral_when_registryInactive(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(usdc), false);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("1201"));
        stablesManager.addCollateral(address(1), address(usdc), 1);
    }

    // Tests if removeCollateral reverts correctly when caller is unauthorized
    function test_removeCollateral_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert(bytes("1000"));
        stablesManager.removeCollateral(address(1), address(2), 1);
    }

    // Tests if removeCollateral reverts correctly when contract is paused
    function test_removeCollateral_when_paused(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.pause();

        vm.prank(caller, caller);
        vm.expectRevert();
        stablesManager.removeCollateral(address(1), address(2), 1);
    }

    // Tests if removeCollateral reverts correctly when registry is inexistent
    function test_removeCollateral_when_registryInexistent(uint256 _callerId, address _token) public {
        (, address d) = stablesManager.shareRegistryInfo(_token);
        vm.assume(d == address(0));

        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(caller, caller);
        vm.expectRevert(bytes("1201"));
        stablesManager.removeCollateral(address(1), _token, 1);
    }

    // Tests if removeCollateral reverts correctly when registry is inactive
    function test_removeCollateral_when_registryInactive(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(usdc), false);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("1201"));
        stablesManager.removeCollateral(address(1), address(usdc), 1);
    }

    // Tests if removeCollateral reverts correctly when holding will become insolvent after collateral removal
    function test_removeCollateral_when_insolvent(
        uint256 _callerId,
        address _user,
        uint256 _mintAmount,
        uint256 _removeAmount
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        _removeAmount = bound(_removeAmount, 1, _mintAmount * 2);

        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(_user, _user);
        holdingManager.borrow(collateral, _mintAmount, 0, true);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3009"));
        stablesManager.removeCollateral(holding, collateral, _removeAmount);

        assertEq(
            ISharesRegistry(registries[collateral]).collateral(holding),
            _mintAmount * 2,
            "Collateral removed incorrectly"
        );
    }

    // Tests if removeCollateral works correctly when authorized
    function test_removeCollateral_when_authorized(
        uint256 _callerId,
        address _user,
        uint256 _mintAmount,
        uint256 _removeAmount
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        _removeAmount = bound(_removeAmount, 1, _mintAmount * 2);

        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        vm.expectEmit();
        emit RemovedCollateral(holding, collateral, _removeAmount);
        stablesManager.removeCollateral(holding, collateral, _removeAmount);

        assertEq(
            ISharesRegistry(registries[collateral]).collateral(holding),
            _mintAmount * 2 - _removeAmount,
            "Collateral removed incorrectly"
        );
    }

    // Tests if forceRemoveCollateral reverts correctly when contract is paused
    function test_forceRemoveCollateral_when_paused(
        address _caller
    ) public {
        vm.prank(OWNER, OWNER);
        stablesManager.pause();

        vm.prank(_caller, _caller);
        vm.expectRevert();
        stablesManager.forceRemoveCollateral(address(1), address(2), 1);
    }

    // Tests if forceRemoveCollateral reverts correctly when registry is inexistent
    function test_forceRemoveCollateral_when_registryInexistent(
        address _token
    ) public {
        (, address d) = stablesManager.shareRegistryInfo(_token);
        vm.assume(d == address(0));

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectRevert(bytes("1201"));
        stablesManager.forceRemoveCollateral(address(1), _token, 1);
    }

    // Tests if forceRemoveCollateral reverts correctly when caller is unauthorized
    function test_forceRemoveCollateral_when_unauthorized(
        address _caller
    ) public {
        vm.assume(_caller != manager.liquidationManager());

        vm.expectRevert(bytes("1000"));
        stablesManager.forceRemoveCollateral(address(1), address(usdc), 1);
    }

    // Tests if forceRemoveCollateral reverts correctly when registry is inactive
    function test_forceRemoveCollateral_when_registryInactive() public {
        vm.prank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(usdc), false);

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectRevert(bytes("1201"));
        stablesManager.forceRemoveCollateral(address(1), address(usdc), 1);
    }

    // Tests if removeCollateral works correctly when authorized
    function test_forceRemoveCollateral_when_authorized(
        address _user,
        uint256 _mintAmount,
        uint256 _removeAmount
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        _removeAmount = bound(_removeAmount, 1, _mintAmount * 2);

        address collateral = address(usdc);
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        vm.expectEmit();
        emit RemovedCollateral(holding, collateral, _removeAmount);
        stablesManager.forceRemoveCollateral(holding, collateral, _removeAmount);

        assertEq(
            ISharesRegistry(registries[collateral]).collateral(holding),
            _mintAmount * 2 - _removeAmount,
            "Collateral removed incorrectly"
        );
    }

    // Tests if borrow reverts correctly when caller is unauthorized
    function test_borrow_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert(bytes("1000"));
        stablesManager.borrow(address(1), address(2), 1, 0, true);
    }

    // Tests if borrow reverts correctly when contract is paused
    function test_borrow_when_paused(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.pause();

        vm.prank(caller, caller);
        vm.expectRevert();
        stablesManager.borrow(address(1), address(2), 1, 0, true);
    }

    // Tests if borrow reverts correctly when invalid amount
    function test_borrow_when_invalidAmount(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3010"));
        stablesManager.borrow(address(1), address(2), 0, 0, true);
    }

    // Tests if borrow reverts correctly when  registry is inactive
    function test_borrow_when_registryInactive(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(usdc), false);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("1201"));
        stablesManager.borrow(address(1), address(2), 1, 0, true);
    }

    // Tests if borrow reverts correctly when insolvent
    function test_borrow_when_insolvent(address _user, uint256 _mintAmount, uint256 _callerId) public {
        vm.assume(_user != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        address collateral = address(usdc);

        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3009"));
        stablesManager.borrow(holding, collateral, _mintAmount * 2, 0, true);
    }

    // Tests if borrow works correctly when authorized
    function test_borrow_when_authorized(
        address _user,
        uint256 _mintAmount,
        bool _mintToUser,
        uint256 _callerId
    ) public {
        vm.assume(_user != address(0));
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        address collateral = address(usdc);

        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        vm.expectEmit();
        emit Borrowed(holding, _mintAmount, _mintToUser);
        stablesManager.borrow(holding, collateral, _mintAmount, 0, _mintToUser);

        assertEq(jUsd.balanceOf(_mintToUser ? _user : holding), _mintAmount, "Borrow failed when authorized");
        assertEq(stablesManager.totalBorrowed(collateral), _mintAmount, "Total borrowed wasn't updated after borrow");
    }

    // Tests if repay reverts correctly when caller is unauthorized
    function test_repay_when_unauthorized(
        address _caller
    ) public onlyNotAllowed(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert(bytes("1000"));
        stablesManager.repay(address(1), address(2), 1, address(3));
    }

    // Tests if repay reverts correctly when contract is paused
    function test_repay_when_paused(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.pause();

        vm.prank(caller, caller);
        vm.expectRevert();
        stablesManager.repay(address(1), address(2), 1, address(3));
    }

    // Tests if repay reverts correctly when  registry is inactive
    function test_repay_when_registryInactive(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(OWNER, OWNER);
        stablesManager.registerOrUpdateShareRegistry(registries[address(usdc)], address(usdc), false);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("1201"));
        stablesManager.repay(address(1), address(2), 1, address(3));
    }

    // Tests if repay reverts correctly when no debt
    function test_repay_when_noDebt(
        uint256 _callerId
    ) public {
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3011"));
        stablesManager.repay(address(1), address(usdc), 0, address(3));
    }

    // Tests if repay reverts correctly when amount to repay > borrowed
    function test_repay_when_amountTooBig(
        address _user,
        uint256 _mintAmount,
        bool _mintToUser,
        uint256 _callerId
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        address collateral = address(usdc);
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        stablesManager.borrow(holding, collateral, _mintAmount, 0, _mintToUser);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("2003"));
        stablesManager.repay(holding, collateral, _mintAmount + 1, holding);
    }

    // Tests if repay reverts correctly when invalid amount
    function test_repay_when_invalidAmount(
        address _user,
        uint256 _mintAmount,
        bool _mintToUser,
        uint256 _callerId
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        address collateral = address(usdc);
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        stablesManager.borrow(holding, collateral, _mintAmount, 0, _mintToUser);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3012"));
        stablesManager.repay(holding, collateral, 0, holding);
    }

    // Tests if repay reverts correctly when burnFrom == address(0)
    function test_repay_when_burnFrom0(
        address _user,
        uint256 _mintAmount,
        bool _mintToUser,
        uint256 _callerId
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        address collateral = address(usdc);
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address holding = initiateUser(_user, collateral, _mintAmount);

        vm.prank(caller, caller);
        stablesManager.borrow(holding, collateral, _mintAmount, 0, _mintToUser);

        vm.prank(caller, caller);
        vm.expectRevert(bytes("3000"));
        stablesManager.repay(holding, collateral, 1, address(0));
    }

    // Tests if repay works correctly when authorized
    function test_repay_when_authorized(
        address _user,
        uint256 _mintAmount,
        uint256 _repayAmount,
        bool _mintToUser,
        uint256 _callerId
    ) public {
        vm.assume(_user != address(0));
        _mintAmount = bound(_mintAmount, 200e18, 100_000e18);
        _repayAmount = _mintAmount;
        address collateral = address(usdc);
        address caller = allowedCallers[bound(_callerId, 0, allowedCallers.length - 1)];
        address holding = initiateUser(_user, collateral, _mintAmount);
        address burnFrom = _mintToUser ? _user : holding;

        vm.prank(caller, caller);
        stablesManager.borrow(holding, collateral, _mintAmount, 0, _mintToUser);

        uint256 balanceBeforeRepay = jUsd.balanceOf(burnFrom);
        uint256 totalBorrowedBeforeRepay = stablesManager.totalBorrowed(collateral);

        vm.prank(caller, caller);
        vm.expectEmit();
        emit Repaid(holding, _repayAmount, burnFrom);
        stablesManager.repay(holding, collateral, _repayAmount, burnFrom);

        assertEq(jUsd.balanceOf(burnFrom), balanceBeforeRepay - _repayAmount, "Repay failed when authorized");
        assertEq(
            stablesManager.totalBorrowed(collateral),
            totalBorrowedBeforeRepay - _repayAmount,
            "Total borrowed wasn't updated after repay"
        );
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        stablesManager.renounceOwnership();
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

    // Utility functions

    function _getSolvencyRatio(address _holding, ISharesRegistry registry) private view returns (uint256) {
        uint256 _colRate = registry.getConfig().collateralizationRate;
        uint256 _exchangeRate = registry.getExchangeRate();

        uint256 _result = (
            (1e18 * registry.collateral(_holding) * _exchangeRate * _colRate)
                / (manager.EXCHANGE_RATE_PRECISION() * manager.PRECISION())
        ) / 1e18;

        _result = _transformTo18Decimals(_result, IERC20Metadata(registry.token()).decimals());

        return _result;
    }

    function _transformTo18Decimals(uint256 _amount, uint256 _decimals) private pure returns (uint256) {
        uint256 result = _amount;

        if (_decimals < 18) {
            result = result * (10 ** (18 - _decimals));
        } else if (_decimals > 18) {
            result = result / (10 ** (_decimals - 18));
        }

        return result;
    }
}
