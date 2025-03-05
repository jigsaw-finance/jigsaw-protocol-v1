// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import { TickMath } from "../utils/TickMath.sol";
import { IUniswapV3Factory } from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import { IQuoterV2 } from "@uniswap/v3-periphery/contracts/interfaces/IQuoterV2.sol";

import { HoldingManager } from "../../src/HoldingManager.sol";

import { JigsawUSD } from "../../src/JigsawUSD.sol";
import { Manager } from "../../src/Manager.sol";
import { ManagerContainer } from "../../src/ManagerContainer.sol";
import { StablesManager } from "../../src/StablesManager.sol";
import { StrategyManager } from "../../src/StrategyManager.sol";
import { SwapManager } from "../../src/SwapManager.sol";
import { ISwapManager } from "../../src/interfaces/core/ISwapManager.sol";

import { INonfungiblePositionManager } from "../utils/INonfungiblePositionManager.sol";
import { SampleOracle } from "../utils/mocks/SampleOracle.sol";

interface IUSDC is IERC20Metadata {
    function balanceOf(
        address account
    ) external view returns (uint256);
    function mint(address to, uint256 amount) external;
    function configureMinter(address minter, uint256 minterAllowedAmount) external;
    function masterMinter() external view returns (address);
}

contract SwapManagerTest is Test {
    event SwapRouterUpdated(address indexed oldAddress, address indexed newAddress);

    HoldingManager public holdingManager;
    IUniswapV3Factory public uniswapFactory;
    IQuoterV2 public quoter;
    IUSDC public usdc;
    IERC20Metadata public weth;
    StablesManager public stablesManager;
    StrategyManager public strategyManager;
    SwapManager public swapManager;
    JigsawUSD public jUsd;
    Manager public manager;
    ManagerContainer public managerContainer;

    address USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address USDT = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;
    address USDT_USDC_POOL = 0xbE3aD6a5669Dc0B8b12FeBC03608860C31E2eef6;
    address UniswapSwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    function setUp() public {
        vm.createSelectFork(vm.envString("ARBITRUM_RPC_URL"), 172_364_769);

        uniswapFactory = IUniswapV3Factory(0x1F98431c8aD98523631AE4a59f267346ea31F984);
        quoter = IQuoterV2(0x61fFE014bA17989E743c5F6cB21bF9697530B21e);
        usdc = IUSDC(USDC);
        weth = IERC20Metadata(0x82aF49447D8a07e3bd95BD0d56f35241523fBab1);
        manager = new Manager(address(this), USDC, address(weth), address(1), bytes(""));
        managerContainer = new ManagerContainer(address(this), address(manager));
        swapManager =
            new SwapManager(address(this), address(uniswapFactory), UniswapSwapRouter, address(managerContainer));
        jUsd = new JigsawUSD(address(this), address(managerContainer));
        stablesManager = new StablesManager(address(this), address(managerContainer), address(jUsd));
        holdingManager = new HoldingManager(address(this), address(managerContainer));
        strategyManager = new StrategyManager(address(this), address(managerContainer));

        manager.setHoldingManager(address(holdingManager));
        manager.setStablecoinManager(address(stablesManager));
        manager.setSwapManager(address(swapManager));
        manager.setStrategyManager(address(strategyManager));
    }

    // Tests if initial state of the contract is correct
    function test_swapManager_initialState() public {
        assertEq(swapManager.swapRouter(), UniswapSwapRouter, "Initial state incorrect");
    }

    // Tests if the SwapRouter is set correctly
    function test_setSwapRouter_when_authorized() public {
        address newAddr = vm.addr(uint256(keccak256(bytes("New Address"))));
        vm.expectEmit(true, false, false, false, (address(swapManager)));
        emit SwapRouterUpdated(swapManager.swapRouter(), newAddr);

        swapManager.setSwapRouter(newAddr);

        assertEq(swapManager.swapRouter(), newAddr, "Swap Router's not changed when authorized");
    }

    // Tests if the function reverts correctly if the caller is unauthorized
    function test_setSwapRouter_when_unauthorized() public {
        address caller = vm.addr(uint256(keccak256(bytes("Unauthprized caller address"))));
        address prevAddr = swapManager.swapRouter();
        vm.prank(caller, caller);
        vm.expectRevert();

        swapManager.setSwapRouter(address(1));

        assertEq(prevAddr, swapManager.swapRouter(), "Swap Router's changed when unauthorized");
    }

    // Tests if the function reverts correctly if the new address is address(0)
    function test_setSwapRouter_when_addressZero() public {
        address newAddr = address(0);
        address prevAddr = swapManager.swapRouter();

        vm.expectRevert(bytes("3000"));
        swapManager.setSwapRouter(newAddr);

        assertEq(swapManager.swapRouter(), prevAddr, "Swap Router's changed to address(0)");
    }

    // Tests if the function reverts correctly if the new address is previous address
    function test_setSwapRouter_when_prevAddress() public {
        address prevAddr = swapManager.swapRouter();
        address newAddr = prevAddr;

        vm.expectRevert(bytes("3017"));
        swapManager.setSwapRouter(newAddr);

        assertEq(swapManager.swapRouter(), prevAddr, "Swap Router's changed");
    }

    // Tests if the function reverts correctly if the caller is unauthorized
    function test_swapExactOutputMultihop_when_unauthorized() public {
        _createJUsdUsdcPool();
        address caller = vm.addr(uint256(keccak256(bytes("Unauthorized caller address"))));
        bytes memory swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC);
        vm.prank(caller, caller);
        vm.expectRevert(bytes("1000"));
        swapManager.swapExactOutputMultihop(USDC, swapPath, address(1), block.timestamp, 1, 1);
    }

    // Tests if the function refunds user when there's more funds sent than needed
    function test_swapExactOutputMultihop_when_refund(
        uint256 _amountOut
    ) public {
        (address pool,) = _createJUsdUsdcPool();
        address tokenOut = address(jUsd);
        vm.assume(_amountOut > 1e6 && _amountOut < IERC20Metadata(tokenOut).balanceOf(pool) / 10);

        bytes memory swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC);
        uint256 amountInMaximum = _amountOut * 10;
        address user = vm.addr(uint256(keccak256(bytes("User address"))));

        vm.prank(user, user);
        address userHolding = holdingManager.createHolding();

        uint256 expectedTokenOutBalance = IERC20Metadata(tokenOut).balanceOf(userHolding) + _amountOut;

        _getUSDC(userHolding, amountInMaximum);
        uint256 tokenInBalanceBefore = IERC20Metadata(USDC).balanceOf(userHolding);

        // Execute swapExactOutputMultihop on Uniswap.
        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        uint256 amountIn = swapManager.swapExactOutputMultihop(
            USDC, swapPath, userHolding, block.timestamp, _amountOut, amountInMaximum
        );

        assertEq(
            expectedTokenOutBalance,
            IERC20Metadata(tokenOut).balanceOf(userHolding),
            "Inccorect tokenOut balance after swap"
        );
        assertEq(
            IERC20Metadata(USDC).balanceOf(userHolding),
            tokenInBalanceBefore - amountIn,
            "Inccorect tokenIn balance after swap"
        );
    }

    // Tests if the function works correctly when no refund is needed
    function test_swapExactOutputMultihop_when_NoRefund(
        uint256 _amountOut
    ) public {
        (address pool,) = _createJUsdUsdcPool();
        address tokenOut = address(jUsd);
        vm.assume(_amountOut > 1e6 && _amountOut < IERC20Metadata(tokenOut).balanceOf(pool) / 10);

        bytes memory swapPath = abi.encodePacked(address(jUsd), uint24(100), USDC);

        (uint256 amountInMaximum,,,) = quoter.quoteExactOutput(swapPath, _amountOut);

        address user = vm.addr(uint256(keccak256(bytes("User address"))));

        vm.prank(user, user);
        address userHolding = holdingManager.createHolding();

        uint256 expectedTokenOutBalance = IERC20Metadata(tokenOut).balanceOf(userHolding) + _amountOut;

        _getUSDC(userHolding, amountInMaximum);
        uint256 tokenInBalanceBefore = IERC20Metadata(USDC).balanceOf(userHolding);

        // Execute swapExactOutputMultihop on Uniswap.
        vm.prank(manager.liquidationManager(), manager.liquidationManager());
        uint256 amountIn = swapManager.swapExactOutputMultihop(
            USDC, swapPath, userHolding, block.timestamp, _amountOut, amountInMaximum
        );

        assertEq(
            expectedTokenOutBalance,
            IERC20Metadata(tokenOut).balanceOf(userHolding),
            "Inccorect tokenOut balance after swap"
        );
        assertEq(
            IERC20Metadata(USDC).balanceOf(userHolding),
            tokenInBalanceBefore - amountIn,
            "Inccorect tokenIn balance after swap"
        );
    }

    //Tests if renouncing ownership reverts with error code 1000
    function test_renounceOwnership() public {
        vm.expectRevert(bytes("1000"));
        swapManager.renounceOwnership();
    }

    // Utility functions

    function _getUSDC(address _receiver, uint256 amount) internal {
        vm.prank(usdc.masterMinter());
        usdc.configureMinter(_receiver, type(uint256).max);

        vm.prank(_receiver);
        usdc.mint(_receiver, amount);
    }

    // crestes Uniswap pool for jUsd and initiates it with volume of {uniswapPoolCap}
    function _createJUsdUsdcPool() internal returns (address pool, uint256 tokenId) {
        INonfungiblePositionManager nonfungiblePositionManager =
            INonfungiblePositionManager(0xC36442b4a4522E871399CD717aBDD847Ab11FE88);

        uint256 uniswapPoolCap = 1_000_000_000_000_000;

        address token0 = address(jUsd);
        address token1 = USDC;

        uint256 jUsdAmount = uniswapPoolCap * 10 ** jUsd.decimals();
        uint256 usdcAmount = uniswapPoolCap * 10 ** usdc.decimals();
        uint24 fee = 100;
        uint160 sqrtPriceX96 = 79_228_162_514_264_337_593_543; //price of approx 1 to 1

        pool = nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, sqrtPriceX96);

        //get usdc and jUsd and approve spending
        deal(address(jUsd), address(this), jUsdAmount * 2, true);
        _getUSDC(address(this), usdcAmount * 2);

        jUsd.approve(address(nonfungiblePositionManager), type(uint256).max);
        usdc.approve(address(nonfungiblePositionManager), type(uint256).max);

        (tokenId,,,) = nonfungiblePositionManager.mint(
            INonfungiblePositionManager.MintParams(
                token0,
                token1,
                fee,
                TickMath.MIN_TICK,
                TickMath.MAX_TICK,
                jUsdAmount,
                usdcAmount,
                0,
                0,
                address(this),
                block.timestamp + 3600
            )
        );
    }
}
