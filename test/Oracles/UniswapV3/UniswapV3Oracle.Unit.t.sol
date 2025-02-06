// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { UniswapV3Oracle } from "src/oracles/uniswap/UniswapV3Oracle.sol";
import { IUniswapV3Oracle } from "src/oracles/uniswap/interfaces/IUniswapV3Oracle.sol";

contract UniswapV3OracleUnitTest is Test {
    address internal constant OWNER = address(uint160(uint256(keccak256("owner"))));

    address internal constant jUSD = 0xdAC17F958D2ee523a2206206994597C13D831ec7; // pretend that USDT is jUSD
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant USDC_POOL = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6; // USDT/USDC pool
    address internal constant WETH_POOL = 0x11b815efB8f581194ae79006d24E0d814B7697F6; // USDT/WETH pool

    UniswapV3Oracle internal uniswapOracle;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 21_722_108);
        uniswapOracle =
            new UniswapV3Oracle({ _initialOwner: OWNER, _jUSD: jUSD, _quoteToken: USDC, _uniswapV3Pool: USDC_POOL });
    }

    function test_uniswap_peek_when_smallQuoteTokenDecimals() public {
        (bool success, uint256 rate) = uniswapOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 1_000_000_000_000_000_000, "Rate is wrong");
    }

    function test_uniswap_peek_when_sameQuoteTokenDecimals() public {
        uniswapOracle =
            new UniswapV3Oracle({ _initialOwner: OWNER, _jUSD: WETH, _quoteToken: jUSD, _uniswapV3Pool: WETH_POOL });

        (bool success, uint256 rate) = uniswapOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 3_194_542_585_000_000_000_000, "Rate is wrong");
    }

    function test_uniswap_peek_when_multiplePools() public {
        address[] memory pools = new address[](1);
        pools[0] = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;
        vm.expectRevert(IUniswapV3Oracle.InvalidPools.selector);
        vm.prank(OWNER, OWNER);
        uniswapOracle.updatePools({ _newPools: pools });

        pools = new address[](3);
        pools[0] = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;
        vm.expectRevert(IUniswapV3Oracle.InvalidPools.selector);
        vm.prank(OWNER, OWNER);
        uniswapOracle.updatePools({ _newPools: pools });

        pools = new address[](2);
        pools[0] = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6;
        pools[1] = 0x7858E59e0C01EA06Df3aF3D20aC7B0003275D4Bf;

        bytes32 oldPoolsHash = keccak256(abi.encode(uniswapOracle.getPools()));
        bytes32 newPoolsHash = keccak256(abi.encode(pools));

        vm.expectEmit();
        emit IUniswapV3Oracle.PoolsUpdated(oldPoolsHash, newPoolsHash);

        vm.prank(OWNER, OWNER);
        uniswapOracle.updatePools({ _newPools: pools });

        (bool success, uint256 rate) = uniswapOracle.peek("");

        vm.assertEq(success, true, "Peek failed");
        vm.assertEq(rate, 1_000_000_000_000_000_000, "Rate is wrong");
    }
}
