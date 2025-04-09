// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { SharesRegistry } from "../../src/SharesRegistry.sol";
import { ISharesRegistry } from "../../src/interfaces/core/ISharesRegistry.sol";

import "../fixtures/BasicContractsFixture.t.sol";

contract SharesRegistryTest is BasicContractsFixture {
    event ConfigUpdated(
        address indexed token, ISharesRegistry.RegistryConfig oldVal, ISharesRegistry.RegistryConfig newVal
    );
    event OracleDataUpdated();
    event NewOracleDataRequested(bytes newData);
    event NewOracleRequested(address newOracle);
    event OracleUpdated();
    event BorrowedSet(address indexed _holding, uint256 oldVal, uint256 newVal);
    event TimelockAmountUpdated(uint256 oldVal, uint256 newVal);
    event TimelockAmountUpdateRequested(uint256 oldVal, uint256 newVal);

    SharesRegistry internal registry;

    function setUp() public {
        init();
        registry = SharesRegistry(registries[address(usdc)]);
    }

    // Tests if init fails correctly when _manager is address(0)
    function test_init_when_invalidManager() public {
        address owner = address(1);
        address container = address(0);
        address token = address(0);
        address oracle = address(0);
        bytes memory data = "0x0";
        ISharesRegistry.RegistryConfig memory config =
            ISharesRegistry.RegistryConfig({ collateralizationRate: 0, liquidationBuffer: 0, liquidatorBonus: 0 });
        vm.expectRevert(bytes("3065"));
        new SharesRegistry(owner, container, token, oracle, data, config);
    }

    // Tests if init fails correctly when token is address(0)
    function test_init_when_invalidToken() public {
        address owner = address(1);
        address container = address(1);
        address token = address(0);
        address oracle = address(0);
        bytes memory data = "0x0";
        ISharesRegistry.RegistryConfig memory config =
            ISharesRegistry.RegistryConfig({ collateralizationRate: 0, liquidationBuffer: 0, liquidatorBonus: 0 });
        vm.expectRevert(bytes("3001"));
        new SharesRegistry(owner, container, token, oracle, data, config);
    }

    // Tests if init fails correctly when oracle is address(0)
    function test_init_when_invalidOracle() public {
        address owner = address(1);
        address container = address(1);
        address token = address(1);
        address oracle = address(0);
        bytes memory data = "0x0";
        ISharesRegistry.RegistryConfig memory config =
            ISharesRegistry.RegistryConfig({ collateralizationRate: 0, liquidationBuffer: 0, liquidatorBonus: 0 });

        vm.expectRevert(bytes("3034"));
        new SharesRegistry(owner, container, token, oracle, data, config);
    }

    // Tests if init fails correctly when _collateralizationRate is invalid
    function test_init_when_invalidColRate(
        uint256 _colRate
    ) public {
        address owner = address(1);
        address container = address(manager);
        address token = address(1);
        address oracle = address(1);
        bytes memory data = "0x0";

        if (_colRate > 1e5 || _colRate < 20e3) {
            vm.expectRevert(bytes("3066"));
        }

        ISharesRegistry.RegistryConfig memory config = ISharesRegistry.RegistryConfig({
            collateralizationRate: _colRate,
            liquidationBuffer: 0,
            liquidatorBonus: 0
        });

        new SharesRegistry(owner, container, token, oracle, data, config);
    }

    // Tests if requestNewOracle reverts correctly when caller is not authorized
    function test_requestNewOracle_when_unauthorized(
        address _caller
    ) public onlyNotOwner(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert();
        registry.requestNewOracle(address(2));
    }

    // Tests if requestNewOracle reverts correctly when oracle in active change
    function test_requestNewOracle_when_inActiveChange(
        address _oracle
    ) public {
        vm.assume(_oracle != address(0));
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(_oracle);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3093"));
        registry.requestNewOracle(_oracle);
    }

    // Tests if requestNewOracle reverts correctly when time lock is in active change
    function test_requestNewOracle_when_timelockInActiveChange(
        uint256 _newVal
    ) public {
        vm.assume(_newVal != 0);
        vm.prank(registry.owner(), registry.owner());
        registry.requestTimelockAmountChange(_newVal);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3095"));
        registry.requestNewOracle(address(1));
        vm.stopPrank();
    }

    // Tests if requestNewOracle reverts correctly when oracle is address(0)
    function test_requestNewOracle_when_invalidOracle() public {
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3000"));
        registry.requestNewOracle(address(0));
    }

    // Tests if requestNewOracle works correctly when authorized
    function test_requestNewOracle_when_authorized(
        address _oracle
    ) public {
        vm.assume(_oracle != address(0));
        vm.prank(registry.owner(), registry.owner());
        vm.expectEmit();
        emit NewOracleRequested(_oracle);
        registry.requestNewOracle(_oracle);
    }

    // Tests if requestNewOracle works correctly when authorized and oracle wasn't set
    function test_requestNewOracle_when_oldOracleNotUsed(address _oracle, address _otherOracle) public {
        vm.assume(_oracle != address(0));
        vm.assume(_otherOracle != address(0));

        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(_oracle);

        vm.warp(block.timestamp + 4 weeks);

        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(_otherOracle);
    }

    // Tests if setOracle reverts correctly when caller is not authorized
    function test_setOracle_when_unauthorized(
        address _caller
    ) public onlyNotOwner(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert();
        registry.setOracle();
    }

    // Tests if setOracle reverts correctly when change is not requested (not in active change)
    function test_setOracle_when_notInActiveChange() public {
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3094"));
        registry.setOracle();
    }

    // Tests if setOracle reverts correctly when setting before time lock expired
    function test_setOracle_when_early(
        address _oracle
    ) public {
        vm.assume(_oracle != address(0));
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(_oracle);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3066"));
        registry.setOracle();
    }

    // Tests if setOracle works correctly when authorized
    function test_setOracle_when_authorized(
        address _oracle
    ) public {
        vm.assume(_oracle != address(0));
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(_oracle);

        vm.warp(block.timestamp + 2 days);

        vm.prank(registry.owner(), registry.owner());
        vm.expectEmit();
        emit OracleUpdated();
        registry.setOracle();

        assertEq(address(registry.oracle()), _oracle, "Oracle was set incorrect");
    }

    // Tests if requestTimelockAmountChange reverts correctly when caller is not authorized
    function test_requestTimelockAmountChange_when_unauthorized(
        address _caller
    ) public onlyNotOwner(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert();
        registry.requestTimelockAmountChange(1);
    }

    // Tests if requestTimelockAmountChange reverts correctly when timelock in active change
    function test_requestTimelockAmountChange_when_inActiveChange(
        uint256 _newVal
    ) public {
        vm.assume(_newVal != 0);
        vm.prank(registry.owner(), registry.owner());
        registry.requestTimelockAmountChange(_newVal);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3095"));
        registry.requestTimelockAmountChange(1);
    }

    // Tests if requestTimelockAmountChange reverts correctly when oracle is in active change
    function test_requestTimelockAmountChange_when_oracleInActiveChange(
        uint256 _newVal
    ) public {
        vm.assume(_newVal != 0);

        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracle(address(1));

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3093"));
        registry.requestTimelockAmountChange(_newVal);
    }

    // Tests if requestTimelockAmountChange reverts correctly when oracle data is in active change
    function test_requestTimelockAmountChange_when_oracleDataInActiveChange(
        uint256 _newVal
    ) public {
        vm.assume(_newVal != 0);

        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracleData(bytes(""));

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3096"));
        registry.requestTimelockAmountChange(_newVal);
    }

    // Tests if requestTimelockAmountChange reverts correctly when _newVal == 0
    function test_requestTimelockAmountChange_when_invalidValue() public {
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("2001"));
        registry.requestTimelockAmountChange(0);
    }

    // Tests if requestTimelockAmountChange works correctly when authorized
    function test_requestTimelockAmountChange_when_authorized(
        uint256 _newVal
    ) public {
        vm.assume(_newVal != 0);
        uint256 oldLock = registry.timelockAmount();
        vm.expectEmit();
        emit TimelockAmountUpdateRequested(oldLock, _newVal);
        vm.prank(registry.owner(), registry.owner());
        registry.requestTimelockAmountChange(_newVal);

        vm.warp(block.timestamp + oldLock);

        vm.prank(registry.owner(), registry.owner());
        vm.expectEmit();
        emit TimelockAmountUpdated(oldLock, _newVal);
        registry.acceptTimelockAmountChange();

        assertEq(registry.timelockAmount(), _newVal);
    }

    // Tests if acceptTimelockAmountChange reverts correctly when caller is not authorized
    function test_acceptTimelockAmountChange_when_unauthorized(
        address _caller
    ) public onlyNotOwner(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert();
        registry.acceptTimelockAmountChange();
    }

    // Tests if acceptTimelockAmountChange reverts correctly when not in active change
    function test_acceptTimelockAmountChange_when_notInActiveChange() public {
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3094"));
        registry.acceptTimelockAmountChange();
    }

    // Tests if setOracle reverts correctly when setting before time lock expired
    function test_acceptTimelockAmountChange_when_early() public {
        vm.prank(registry.owner(), registry.owner());
        registry.requestTimelockAmountChange(1);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3066"));
        registry.acceptTimelockAmountChange();
    }

    // Tests if setCollateralizationRate reverts correctly when caller is not authorized
    function test_setCollateralizationRate_when_unauthorized(
        address _caller
    ) public onlyNotOwner(_caller) {
        vm.prank(_caller, _caller);
        vm.expectRevert();
        registry.updateConfig(
            ISharesRegistry.RegistryConfig({ collateralizationRate: 1, liquidationBuffer: 0, liquidatorBonus: 0 })
        );
    }

    // Tests if setCollateralizationRate reverts correctly when invalid amount
    function test_setCollateralizationRate_when_invalidAmount() public {
        uint256 newVal = 2e5;
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3066"));
        registry.updateConfig(
            ISharesRegistry.RegistryConfig({ collateralizationRate: newVal, liquidationBuffer: 0, liquidatorBonus: 0 })
        );

        newVal = 19e3;
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3066"));
        registry.updateConfig(
            ISharesRegistry.RegistryConfig({ collateralizationRate: newVal, liquidationBuffer: 0, liquidatorBonus: 0 })
        );
    }

    // Tests if setCollateralizationRate works correctly when authorized
    function test_setCollateralizationRate_when_authorized(
        uint256 _newVal
    ) public {
        _newVal = bound(_newVal, 20e3, 1e5);

        ISharesRegistry.RegistryConfig memory updatedConfig =
            ISharesRegistry.RegistryConfig({ collateralizationRate: _newVal, liquidationBuffer: 0, liquidatorBonus: 0 });

        vm.expectEmit();
        emit ConfigUpdated(address(usdc), registry.getConfig(), updatedConfig);

        vm.prank(registry.owner(), registry.owner());
        registry.updateConfig(updatedConfig);

        assertEq(
            registry.getConfig().collateralizationRate,
            _newVal,
            "Collateralization rate incorrect after  setCollateralizationRate"
        );
    }

    // Tests if requestNewOracleData reverts correctly when change is already requested
    function test_requestNewOracleData_when_changeAlreadyRequested() public {
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracleData(bytes(""));

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3096"));
        registry.requestNewOracleData(bytes(""));
    }

    // Tests if requestNewOracleData reverts correctly when timelock is in active change
    function test_requestNewOracleData_when_timelockInActiveChange() public {
        vm.prank(registry.owner(), registry.owner());
        registry.requestTimelockAmountChange(100 days);

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3095"));
        registry.requestNewOracleData(bytes(""));
    }

    // Tests if setOracleData reverts correctly when no oracle data change is requested
    function test_setOracleData_when_noOracleDataActiveChange() public {
        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3094"));
        registry.setOracleData();
    }

    // Tests if setOracleData reverts correctly when time lock has not expired
    function test_setOracleData_when_tooSoon() public {
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracleData(bytes(""));

        vm.prank(registry.owner(), registry.owner());
        vm.expectRevert(bytes("3066"));
        registry.setOracleData();
    }

    // Tests if setOracleData reverts correctly when authorized
    function test_setOracleData_when_authorized() public {
        vm.prank(registry.owner(), registry.owner());
        registry.requestNewOracleData(bytes("New Data"));

        vm.warp(block.timestamp + registry.timelockAmount());

        vm.prank(registry.owner(), registry.owner());
        vm.expectEmit();
        emit OracleDataUpdated();
        registry.setOracleData();

        assertEq(registry.oracleData(), bytes("New Data"), "Wrong new oracle data");
    }

    function test_only_stables_manager(address _holding) public {
        vm.expectRevert(bytes("1000"));
        registry.setBorrowed(_holding, 0);

        vm.expectRevert(bytes("1000"));
        registry.registerCollateral(_holding, 0);

        vm.expectRevert(bytes("1000"));
        registry.unregisterCollateral(_holding, 0);
    }

    modifier onlyNotOwner(
        address _caller
    ) {
        vm.assume(_caller != registry.owner());
        _;
    }
}
